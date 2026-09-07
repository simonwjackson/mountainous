//! Build-time synthetic identities and producer-written grants. Never production data.
use korrid::{
    authorization::{Authorization, AuthorizationContext},
    identity::IdentityState,
};
use nostr::{
    event::{EventBuilder, FinalizeEvent, Kind, Tag},
    key::{Keys, SecretKey},
    types::Timestamp,
};
use std::{fs, os::unix::fs::PermissionsExt, path::PathBuf};

fn keys(number: u8) -> Keys {
    Keys::new(SecretKey::from_hex(&format!("{number:064x}")).unwrap())
}
fn statement(owner: u8, device: &str, status: &str) -> nostr::event::Event {
    EventBuilder::new(Kind::Custom(30078), "")
        .tags([
            Tag::parse(["d", &format!("org.korri.device-owner:{device}")]).unwrap(),
            Tag::parse(["device", device]).unwrap(),
            Tag::parse(["status", status]).unwrap(),
        ])
        .custom_created_at(Timestamp::from(100))
        .finalize(&keys(owner))
        .unwrap()
}
fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let [output, certificate] = args.as_slice() else {
        panic!("fixture output + synthetic certificate required")
    };
    let output = PathBuf::from(output);
    fs::create_dir_all(output.join("identity")).unwrap();
    fs::set_permissions(output.join("identity"), fs::Permissions::from_mode(0o700)).unwrap();
    let device = keys(19).public_key().to_hex();
    let old = statement(3, &device, "owned");
    let new = statement(4, &device, "owned");
    let event: serde_json::Value = serde_json::from_str(&new.as_json()).unwrap();
    let template = serde_json::json!({"kind":event["kind"], "created_at":event["created_at"], "tags":event["tags"], "content":event["content"]});
    let client = keys(23).public_key().to_hex();
    let client_event = statement(4, &client, "owned");
    fs::create_dir_all(output.join("verification-client/identity")).unwrap();
    fs::write(
        output.join("verification-client/identity/device.key"),
        format!("{:064x}\n", 23),
    )
    .unwrap();
    fs::write(
        output.join("verification-client/identity/owner.event.json"),
        client_event.as_json(),
    )
    .unwrap();
    fs::write(output.join("verification-expected.json"), serde_json::json!({"verification_device":client,"verification_event":client_event.id.to_hex()}).to_string()).unwrap();
    fs::write(output.join("old.json"), old.as_json()).unwrap();
    fs::write(output.join("new.json"), new.as_json()).unwrap();
    fs::write(output.join("template.json"), template.to_string()).unwrap();
    fs::write(output.join("identity/device.key"), format!("{:064x}\n", 19)).unwrap();
    fs::write(output.join("identity/owner.event.json"), old.as_json()).unwrap();
    let local = IdentityState::Owned {
        device_public_key: device.clone(),
        owner_public_key: keys(3).public_key().to_hex(),
        event_id: old.id.to_hex(),
        created_at: 100,
    };
    let authorization = Authorization::load(&output).unwrap();
    let peer = keys(6).public_key().to_hex();
    let event = statement(3, &peer, "owned").as_json();
    let revocation = statement(3, &keys(9).public_key().to_hex(), "revoked").as_json();
    let attempt = authorization
        .attempt(&local, &peer, Some(&event), None, &[revocation], 200)
        .unwrap();
    authorization.commit_revocations(&attempt).unwrap();
    let AuthorizationContext::Peer(principal) = attempt.context() else {
        panic!("expected peer")
    };
    authorization
        .record_certificate(
            principal,
            "6832F97F-A2D5-C30B-2B1C-1D4E31150449",
            &fs::read_to_string(certificate).unwrap(),
        )
        .unwrap();
    fs::write(output.join("expected.json"), serde_json::json!({"device":device, "old_event":old.id.to_hex(), "new_event":new.id.to_hex(), "new_owner":keys(4).public_key().to_hex()}).to_string()).unwrap();
}
