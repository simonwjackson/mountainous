//! Producer-linked binding and encrypted peer acceptance. No successful-owner signer.
//! Private client state is independently supplied; only negative probe keys are made here.
use korrid::identity::{DeviceIdentity, OwnerStatementStatus};
use std::io::{self, Read};

fn verify() -> Result<(), ()> {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let [device, owner, event_id, template] = args.as_slice() else {
        return Err(());
    };
    let mut bytes = Vec::new();
    io::stdin()
        .take(65537)
        .read_to_end(&mut bytes)
        .map_err(|_| ())?;
    if bytes.len() > 65536 {
        return Err(());
    }
    let event = std::str::from_utf8(&bytes).map_err(|_| ())?;
    let statement = DeviceIdentity::verify_owner_statement(event, device).map_err(|_| ())?;
    if statement.owner_public_key != *owner
        || statement.event_id != *event_id
        || statement.status != OwnerStatementStatus::Owned
    {
        return Err(());
    }
    if template != "-" {
        // The supervisor supplies a checked immutable public template, never private state.
        let bytes = std::fs::read(template).map_err(|_| ())?;
        if bytes.len() > 65536 {
            return Err(());
        }
        let template = std::str::from_utf8(&bytes).map_err(|_| ())?;
        // Signature, strict owner tags and device binding come from the public
        // producer verifier above. Compare only the externally approved public
        // template projection here; the offline writer independently repeats its
        // private full-template verifier before touching the owner file.
        let event: serde_json::Value = serde_json::from_str(event).map_err(|_| ())?;
        let template: serde_json::Value = serde_json::from_str(template).map_err(|_| ())?;
        let projection = serde_json::json!({
            "kind": event["kind"], "created_at": event["created_at"],
            "tags": event["tags"], "content": event["content"],
        });
        if template != projection {
            return Err(());
        }
    }
    Ok(())
}

// This adapter uses the shipped credentials, wire types, encryption, native client,
// authorization and discovery producers. Only the deliberately compromised owner
// (secret 3) signs negative probes. A successful owner is NEVER generated here.
use korrid::{
    authorization::{authorize, Authorization},
    federation::{
        coordinator::{Discovery, DiscoveryInputs, DiscoveryTiming, FederationResources},
        PeerState,
    },
    identity::IdentityState,
    relay::{RelayList, WebSocketRelayTransport},
    upstream_native::NativeClient,
    upstreams::UpstreamRegistry,
    CatalogSnapshotRequest, MoonlightCertificateProvisionOutcome,
    MoonlightCertificateProvisionRequest, MoonlightCertificateRevokeOutcome,
    MoonlightCertificateRevokeRequest, PeerListOutcome, PeerListRequest, RpcRequest, RpcResponse,
    SessionStatusOutcome, SessionStatusRequest, SourceCatalogState, SourceStreamControlState,
};
use nostr::{
    event::{EventBuilder, FinalizeEvent, Kind, Tag, UnsignedEvent},
    key::{Keys, SecretKey},
    types::Timestamp,
};
use std::{fs, os::unix::fs::PermissionsExt, path::Path, sync::Arc, time::Duration};

fn unix_time() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .expect("clock after epoch")
        .as_secs()
}

fn bound_client(
    root: &Path,
    device: &str,
    owner: &str,
    event: &str,
) -> Result<FederationResources, ()> {
    // The root supervisor first pins nofollow metadata and digests. Repeat the
    // no-create prerequisites here because load() itself permits initialization.
    for name in ["identity/device.key", "identity/owner.event.json"] {
        let info = fs::symlink_metadata(root.join(name)).map_err(|_| ())?;
        if !info.is_file() || info.len() > 65536 {
            return Err(());
        }
    }
    let credentials = FederationResources::open(root).map_err(|_| ())?;
    let identity = credentials
        .credentials
        .identity_snapshot()
        .map_err(|_| ())?;
    match identity.state() {
        IdentityState::Owned {
            device_public_key,
            owner_public_key,
            event_id,
            ..
        } if device_public_key == device && owner_public_key == owner && event_id == event => {
            Ok(credentials)
        }
        _ => Err(()),
    }
}

async fn peer_request(
    resources: &FederationResources,
    host: &str,
    request: RpcRequest,
    denied: bool,
    pass: Option<String>,
) -> Result<Option<RpcResponse>, ()> {
    let credentials = resources.credentials.with_person_pass(pass);
    let encoded = credentials
        .encode_request(host, request, unix_time())
        .map_err(|_| ())?;
    let mut response = reqwest::Client::builder()
        .timeout(Duration::from_secs(5))
        .redirect(reqwest::redirect::Policy::none())
        .build()
        .map_err(|_| ())?
        .post("http://127.0.0.1:39217/peer-rpc")
        .header("content-type", "application/json")
        .body(encoded.event_json.clone())
        .send()
        .await
        .map_err(|_| ())?;
    if denied {
        return if response.status() == reqwest::StatusCode::FORBIDDEN {
            Ok(None)
        } else {
            Err(())
        };
    }
    if response.status() != reqwest::StatusCode::OK {
        return Err(());
    }
    let mut bytes = Vec::new();
    while let Some(chunk) = response.chunk().await.map_err(|_| ())? {
        if bytes.len() + chunk.len() > 262144 {
            return Err(());
        }
        bytes.extend_from_slice(&chunk);
    }
    credentials
        .decode_response(
            host,
            &encoded,
            std::str::from_utf8(&bytes).map_err(|_| ())?,
            unix_time(),
        )
        .map(Some)
        .map_err(|_| ())
}

fn negative_identity(root: &Path, owner: &Keys) -> Result<FederationResources, ()> {
    fs::create_dir(root).map_err(|_| ())?;
    fs::set_permissions(root, fs::Permissions::from_mode(0o700)).map_err(|_| ())?;
    let mut identity = DeviceIdentity::load_or_create(root).map_err(|_| ())?;
    let template = identity
        .owner_statement_template(OwnerStatementStatus::Owned, unix_time())
        .map_err(|_| ())?;
    // Add only the signer field to the producer's exact unsigned template.
    let mut value: serde_json::Value = serde_json::from_str(&template).map_err(|_| ())?;
    value["pubkey"] = owner.public_key().to_hex().into();
    let unsigned: UnsignedEvent = serde_json::from_value(value).map_err(|_| ())?;
    let event = unsigned.finalize(owner).map_err(|_| ())?;
    identity
        .apply_signed_owner_binding(&template, &owner.public_key().to_hex(), &event.as_json())
        .map_err(|_| ())?;
    FederationResources::open(root).map_err(|_| ())
}

async fn local_check(args: &[String]) -> Result<(), ()> {
    let [root, device, owner, event, host, negative, old_binding, host_uuid] = args else {
        return Err(());
    };
    if device == host || owner == "f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9"
    {
        return Err(());
    }
    let credentials = bound_client(Path::new(root), device, owner, event)?;
    if credentials
        .directory
        .peer_is_revoked(host)
        .map_err(|_| ())?
    {
        return Err(());
    }
    let native = NativeClient::new_secure(
        "http://127.0.0.1:39217".into(),
        host.clone(),
        credentials.credentials.clone(),
    );
    let source = native.source_status(host).await.map_err(|_| ())?;
    if !matches!(source.catalog, SourceCatalogState::Available)
        || !matches!(source.stream_control, SourceStreamControlState::Enabled)
    {
        return Err(());
    }
    native.catalog_snapshot().await.map_err(|_| ())?;
    if !native
        .moonlight_certificate_attest(host_uuid)
        .await
        .map_err(|_| ())?
        .matched
    {
        return Err(());
    }
    match peer_request(
        &credentials,
        host,
        RpcRequest::SessionStatus(SessionStatusRequest {}),
        false,
        None,
    )
    .await?
    {
        Some(RpcResponse::SessionStatus(SessionStatusOutcome::Err(error)))
            if error.code == "NoActiveSession" && error.message == "no host launch is active" => {}
        _ => return Err(()),
    }
    match peer_request(
        &credentials,
        host,
        RpcRequest::PeerList(PeerListRequest {}),
        false,
        None,
    )
    .await?
    {
        Some(RpcResponse::PeerList(PeerListOutcome::Ok(_))) => {}
        _ => return Err(()),
    }
    let compromised = Keys::new(SecretKey::from_hex(&format!("{:064x}", 3)).map_err(|_| ())?);
    let negative_root = Path::new(negative);
    let old = negative_identity(&negative_root.join("known-test-owner"), &compromised)?;
    peer_request(
        &old,
        host,
        RpcRequest::CatalogSnapshot(CatalogSnapshotRequest {}),
        true,
        None,
    )
    .await?;
    let guest = negative_identity(&negative_root.join("old-pass-holder"), &Keys::generate())?;
    let now = unix_time();
    // Exact pass contract from authorization.rs::parse_person_pass/pass tests;
    // signatures are produced by nostr, then validated by actual Authorization.
    let pass = EventBuilder::new(Kind::Custom(30079), "")
        .tags([
            Tag::parse([
                "d",
                &format!(
                    "org.korri.person-pass:{}",
                    guest.credentials.public_key().map_err(|_| ())?
                ),
            ])
            .map_err(|_| ())?,
            Tag::parse(["device", &guest.credentials.public_key().map_err(|_| ())?])
                .map_err(|_| ())?,
            Tag::parse(["tier", "guest"]).map_err(|_| ())?,
            Tag::parse(["expires", &(now + 60).to_string()]).map_err(|_| ())?,
            Tag::parse(["scope", "catalog.read"]).map_err(|_| ())?,
        ])
        .custom_created_at(Timestamp::from(now))
        .finalize(&compromised)
        .map_err(|_| ())?
        .as_json();
    let previous = DeviceIdentity::verify_owner_statement(
        &fs::read_to_string(old_binding).map_err(|_| ())?,
        host,
    )
    .map_err(|_| ())?;
    if previous.owner_public_key != compromised.public_key().to_hex()
        || previous.status != OwnerStatementStatus::Owned
    {
        return Err(());
    }
    let prior = IdentityState::Owned {
        device_public_key: host.clone(),
        owner_public_key: previous.owner_public_key,
        event_id: previous.event_id,
        created_at: previous.created_at,
    };
    let authorization =
        Authorization::load(&negative_root.join("old-pass-holder")).map_err(|_| ())?;
    let statement = guest
        .credentials
        .identity_snapshot()
        .map_err(|_| ())?
        .owner_statement_json()
        .ok_or(())?;
    let attempt = authorization
        .attempt(
            &prior,
            &guest.credentials.public_key().map_err(|_| ())?,
            Some(&statement),
            Some(&pass),
            &[],
            now,
        )
        .map_err(|_| ())?;
    authorize(
        attempt.context(),
        &RpcRequest::CatalogSnapshot(CatalogSnapshotRequest {}),
    )
    .map_err(|_| ())?;
    peer_request(
        &guest,
        host,
        RpcRequest::CatalogSnapshot(CatalogSnapshotRequest {}),
        true,
        Some(pass),
    )
    .await?;
    Ok(())
}

async fn certificate_check(args: &[String], provision: bool) -> Result<(), ()> {
    let [root, device, owner, event, host, host_uuid, certificate, server_certificate] = args
    else {
        return Err(());
    };
    if device == host || owner == "f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9"
    {
        return Err(());
    }
    let resources = bound_client(Path::new(root), device, owner, event)?;
    // The supervisor pins these bounded files in its exclusive protected root.
    // Never accept a certificate or server identity returned on stdout as proof.
    let certificate = fs::read_to_string(certificate).map_err(|_| ())?;
    let server_certificate = fs::read_to_string(server_certificate).map_err(|_| ())?;
    if certificate.len() > 65536 || server_certificate.len() > 65536 {
        return Err(());
    }
    let request = if provision {
        RpcRequest::MoonlightCertificateProvision(MoonlightCertificateProvisionRequest {
            host_uuid: host_uuid.clone(),
            client_certificate: certificate,
        })
    } else {
        RpcRequest::MoonlightCertificateRevoke(MoonlightCertificateRevokeRequest {
            host_uuid: host_uuid.clone(),
            client_certificate: certificate,
        })
    };
    // Existing producer envelope, signatures, replay binding and encrypted response
    // validation. No local plaintext /rpc or certificate-control provisioning.
    match peer_request(&resources, host, request, false, None).await? {
        Some(RpcResponse::MoonlightCertificateProvision(
            MoonlightCertificateProvisionOutcome::Ok(value),
        )) if provision && value.server_certificate == server_certificate => Ok(()),
        Some(RpcResponse::MoonlightCertificateRevoke(MoonlightCertificateRevokeOutcome::Ok(
            value,
        ))) if !provision && value.removed => Ok(()),
        _ => Err(()),
    }
}

async fn relay_check(args: &[String]) -> Result<(), ()> {
    let [root, device, owner, event, host, relays] = args else {
        return Err(());
    };
    let root = Path::new(root);
    let resources = bound_client(root, device, owner, event)?;
    // Local encrypted checks do not populate this producer directory. Require
    // pristine peer memory so only a newly observed relay announcement can
    // satisfy the first discovery wait. Never clear or adopt cached endpoints.
    if !resources.directory.snapshot().map_err(|_| ())?.is_empty() {
        return Err(());
    }
    let inputs = DiscoveryInputs {
        relays: RelayList::from_linux_environment(Some(relays)).map_err(|_| ())?,
        advertised_endpoints: vec![],
        label: None,
        moonlight_address: None,
    };
    if inputs.relays.is_none() {
        return Err(());
    }
    let task = Discovery::new(
        resources.directory.clone(),
        resources.credentials.clone(),
        Arc::new(move || Ok(inputs.clone())),
        Arc::new(WebSocketRelayTransport::new()),
        DiscoveryTiming {
            poll: Duration::from_secs(1),
            ..DiscoveryTiming::default()
        },
        Arc::new(unix_time),
    )
    .spawn();
    let deadline = tokio::time::Instant::now() + Duration::from_secs(150);
    loop {
        let peers = resources.directory.snapshot().map_err(|_| ())?;
        if peers
            .iter()
            .any(|peer| peer.device_public_key == *host && peer.current_endpoint.is_some())
        {
            break;
        }
        if tokio::time::Instant::now() > deadline {
            return Err(());
        }
        tokio::time::sleep(Duration::from_millis(250)).await;
    }
    let registry = UpstreamRegistry::new_secure(vec![], resources.credentials.clone())
        .with_federation(resources.directory.clone());
    let source = registry.source_status(host).await.map_err(|_| ())?;
    if !matches!(source.catalog, SourceCatalogState::Available)
        || !matches!(source.stream_control, SourceStreamControlState::Enabled)
    {
        return Err(());
    }
    if !resources
        .directory
        .snapshot()
        .map_err(|_| ())?
        .iter()
        .any(|peer| peer.device_public_key == *host && matches!(peer.state, PeerState::Ready))
    {
        return Err(());
    }
    match peer_request(
        &resources,
        host,
        RpcRequest::PeerList(PeerListRequest {}),
        false,
        None,
    )
    .await?
    {
        Some(RpcResponse::PeerList(PeerListOutcome::Ok(list)))
            if list
                .peers
                .iter()
                .any(|peer| peer.device_public_key == *device && peer.last_error.is_none()) => {}
        _ => return Err(()),
    }
    task.shutdown().await.map_err(|_| ())?;
    drop(registry);
    drop(resources);
    // Reopen actual producer memory with NO discovery task. Remembered routing
    // must authenticate again and move Loading to Ready, not trust a saved label.
    let recovered = FederationResources::open(root).map_err(|_| ())?;
    let registry = UpstreamRegistry::new_secure(vec![], recovered.credentials.clone())
        .with_federation(recovered.directory.clone());
    registry.source_status(host).await.map_err(|_| ())?;
    if !recovered
        .directory
        .snapshot()
        .map_err(|_| ())?
        .iter()
        .any(|peer| peer.device_public_key == *host && matches!(peer.state, PeerState::Ready))
    {
        return Err(());
    }
    Ok(())
}

#[tokio::main]
async fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let (result, message) = match args.first().map(String::as_str) {
        Some("local-check") => (
            local_check(&args[1..]).await,
            "verified encrypted owner success and fresh old-owner/pass rejection",
        ),
        Some("certificate-provision") => (
            certificate_check(&args[1..], true).await,
            "verified authenticated certificate provision and exact server certificate",
        ),
        Some("certificate-revoke") => (
            certificate_check(&args[1..], false).await,
            "verified authenticated temporary certificate removal",
        ),
        Some("relay-check") => (
            relay_check(&args[1..]).await,
            "verified configured relay discovery and remembered native recovery",
        ),
        _ => (verify(), "verified exact owned binding"),
    };
    if result.is_err() {
        eprintln!("producer acceptance evidence refused");
        std::process::exit(1);
    }
    println!("{message}");
}
