#!/usr/bin/env python3
"""Hold the notification view to the socket schema, with a reference validator.

    notification-schema-check.py SCHEMA FAKE_NOTIFYD CORPUS_OUT

SCHEMA is packages/notify-sync/schema/ui-socket.v1.json. This script:

1. checks that the schema is valid JSON Schema 2020-12;
2. validates every event the development daemon (FAKE_NOTIFYD --dump) can
   send against $defs/daemonEvent, so the fixtures the screenshots use are
   real protocol;
3. writes CORPUS_OUT: those lines plus mutations of them, and client
   operations, each labelled valid or invalid by python jsonschema.
   notification-model.test.js then requires notification-model.js to give
   the same verdict on every line.
"""

import copy
import json
import subprocess
import sys
import tempfile

from jsonschema import Draft202012Validator


def validator_for(schema, name):
    """A validator for $defs[name], with the schema's own $defs in scope."""
    rooted = {k: v for k, v in schema.items() if k != "oneOf"}
    rooted["$ref"] = "#/$defs/" + name
    return Draft202012Validator(rooted)


def label(validator, value, why):
    return {"line": json.dumps(value), "valid": validator.is_valid(value), "why": why}


def item_mutations(item):
    """(why, item) pairs, each one change away from a valid item."""
    out = []
    for key in item:
        broken = copy.deepcopy(item)
        del broken[key]
        out.append((f"item without {key}", broken))
    changes = [
        ("extra item field", {"colour": "red"}),
        ("string id", {"id": str(item["id"])}),
        ("id 0", {"id": 0}),
        ("id past uint32", {"id": 4294967296}),
        ("fractional id", {"id": 1.5}),
        ("urgency 3", {"urgency": 3}),
        ("origin elsewhere", {"origin": "phone"}),
        ("seq with a space", {"seq": "a b"}),
        ("seq of 65 chars", {"seq": "a" * 65}),
        ("empty seq", {"seq": ""}),
        ("image as a number", {"image": 5}),
        ("null summary", {"summary": None}),
        ("string sender_alive", {"sender_alive": "yes"}),
        ("fractional created", {"created": 1.5}),
        ("action without label", {"actions": [{"key": "x"}]}),
        ("action with extra field", {"actions": [{"key": "x", "label": "X", "icon": "y"}]}),
        ("action not an object", {"actions": ["x"]}),
    ]
    for why, change in changes:
        broken = copy.deepcopy(item)
        broken.update(change)
        out.append((why, broken))
    return out


def main():
    schema_path, fake, corpus_path = sys.argv[1:4]
    with open(schema_path) as f:
        schema = json.load(f)
    Draft202012Validator.check_schema(schema)
    events = validator_for(schema, "daemonEvent")
    ops = validator_for(schema, "clientOperation")

    with tempfile.TemporaryDirectory() as assets:
        dump = subprocess.run([sys.executable, fake, "--dump", "--assets", assets],
                              check=True, capture_output=True, text=True).stdout
    lines = [json.loads(line) for line in dump.splitlines() if line.strip()]
    kinds = {line["type"] for line in lines}
    assert kinds == {"snapshot", "upsert", "remove", "status"}, kinds

    failures = []
    for value in lines:
        for error in events.iter_errors(value):
            failures.append(f"{value.get('type')}: {error.message} at {list(error.absolute_path)}")
    if failures:
        sys.exit("fake notifyd output breaks the schema:\n  " + "\n  ".join(failures[:20]))

    corpus = [label(events, value, "fake notifyd " + value["type"]) for value in lines]

    upsert = next(v for v in lines if v["type"] == "upsert")
    snapshot = next(v for v in lines if v["type"] == "snapshot" and v["items"])
    remove = next(v for v in lines if v["type"] == "remove")
    status = next(v for v in lines if v["type"] == "status")
    for why, item in item_mutations(upsert["item"]):
        corpus.append(label(events, dict(upsert, item=item), "upsert, " + why))
    for why, item in item_mutations(snapshot["items"][0])[:6]:
        corpus.append(label(events, dict(snapshot, items=[item] + snapshot["items"][1:]), "snapshot, " + why))
    event_changes = [
        ("upsert without fresh", {k: v for k, v in upsert.items() if k != "fresh"}),
        ("upsert with a string fresh", dict(upsert, fresh="true")),
        ("upsert with an extra field", dict(upsert, seen=True)),
        ("unknown event type", dict(upsert, type="clear")),
        ("no type", {k: v for k, v in upsert.items() if k != "type"}),
        ("snapshot without status", {k: v for k, v in snapshot.items() if k != "status"}),
        ("snapshot with items not a list", dict(snapshot, items={})),
        ("status without last_error", dict(status, status={"server": "connected", "outbox": 0})),
        ("status with negative outbox", dict(status, status={"server": "connected", "outbox": -1, "last_error": None})),
        ("status with unknown server", dict(status, status={"server": "down", "outbox": 0, "last_error": None})),
        ("status with numeric last_error", dict(status, status={"server": "connected", "outbox": 0, "last_error": 5})),
        ("remove without reason", {k: v for k, v in remove.items() if k != "reason"}),
        ("remove with negative reason", dict(remove, reason=-1)),
        ("remove with id 0", dict(remove, id=0)),
        ("an op on the event stream", {"op": "subscribe"}),
        ("empty object", {}),
        ("empty snapshot", {"type": "snapshot", "items": [], "status": status["status"]}),
        ("status unreachable with error", {"type": "status", "status": {"server": "unreachable", "outbox": 9, "last_error": "x"}}),
    ]
    for why, value in event_changes:
        corpus.append(label(events, value, why))

    op_cases = [
        ("subscribe", {"op": "subscribe"}),
        ("dismiss", {"op": "dismiss", "id": 12}),
        ("action", {"op": "action", "id": 12, "key": "reply"}),
        ("action with an empty key", {"op": "action", "id": 12, "key": ""}),
        ("dismiss_all", {"op": "dismiss_all"}),
        ("dismiss without id", {"op": "dismiss"}),
        ("dismiss with id 0", {"op": "dismiss", "id": 0}),
        ("dismiss with a string id", {"op": "dismiss", "id": "12"}),
        ("action without key", {"op": "action", "id": 12}),
        ("subscribe with an extra field", {"op": "subscribe", "since": 3}),
        ("unknown op", {"op": "clear", "id": 12}),
        ("an event on the op stream", {"type": "status", "status": status["status"]}),
    ]
    op_corpus = [label(ops, value, why) for why, value in op_cases]

    # The mutations must exercise both verdicts, or the corpus proves little.
    for name, entries in (("events", corpus), ("ops", op_corpus)):
        verdicts = {entry["valid"] for entry in entries}
        assert verdicts == {True, False}, (name, verdicts)

    with open(corpus_path, "w") as f:
        json.dump({"events": corpus, "ops": op_corpus}, f)
    invalid = sum(1 for e in corpus if not e["valid"])
    print(f"notification-view schema: {len(lines)} fake notifyd events valid; "
          f"corpus {len(corpus)} events ({invalid} invalid), {len(op_corpus)} ops")


if __name__ == "__main__":
    main()
