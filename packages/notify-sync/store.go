package notifysync

import (
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"

	_ "modernc.org/sqlite"
)

type record struct {
	Revision  uint64 `json:"revision"`
	Item      Item   `json:"item"`
	Sender    string `json:"sender"`
	Open      bool   `json:"open"`
	Pending   string `json:"pending"`
	Published bool   `json:"published"`
	PubID     string `json:"pub_id"`
	PubSeen   bool   `json:"pub_seen"`
	Expires   int64  `json:"expires"`
}
type state struct {
	Session         string             `json:"session"`
	Nonce           string             `json:"nonce"`
	Next            uint32             `json:"next"`
	Cursors         map[string]string  `json:"cursors"`
	Controls        []Control          `json:"controls"`
	Records         map[uint32]*record `json:"-"`
	Seen            map[string]bool    `json:"-"`
	originalRecords map[uint32]string
	originalSeen    map[string]bool
}

// Store checkpoints changed records, replay cursors, ID allocation, action
// de-duplication and the outbox in one transaction. Working copies are not a
// cache: SQLite is the source of truth. Empty network polls never read bodies.
type Store struct{ db *sql.DB }

func OpenStore(path string) (*Store, error) {
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		return nil, err
	}
	db, err := sql.Open("sqlite", path)
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(1)
	_, err = db.Exec(`PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; PRAGMA busy_timeout=5000;
 CREATE TABLE IF NOT EXISTS meta (id INTEGER PRIMARY KEY CHECK(id=1), data BLOB NOT NULL);
 CREATE TABLE IF NOT EXISTS records (id INTEGER PRIMARY KEY, data BLOB NOT NULL, pending TEXT NOT NULL);
 CREATE TABLE IF NOT EXISTS seen (id TEXT PRIMARY KEY);`)
	if err != nil {
		db.Close()
		return nil, err
	}
	s := &Store{db: db}
	var count int
	err = db.QueryRow(`SELECT count(*) FROM meta`).Scan(&count)
	if err == nil && count == 0 {
		nonce := make([]byte, 6)
		_, err = rand.Read(nonce)
		if err == nil {
			v := state{Nonce: hex.EncodeToString(nonce), Next: 1, Cursors: map[string]string{}}
			var b []byte
			b, err = json.Marshal(v)
			if err == nil {
				_, err = db.Exec(`INSERT INTO meta VALUES(1,?)`, b)
			}
		}
	}
	if err != nil {
		db.Close()
		return nil, err
	}
	return s, nil
}
func (s *Store) Close() error { return s.db.Close() }
func (s *Store) loadMeta() (*state, error) {
	var b []byte
	if err := s.db.QueryRow(`SELECT data FROM meta WHERE id=1`).Scan(&b); err != nil {
		return nil, err
	}
	var v state
	if err := json.Unmarshal(b, &v); err != nil {
		return nil, err
	}
	return &v, nil
}
func (s *Store) saveMeta(v *state) error {
	b, err := json.Marshal(v)
	if err != nil {
		return err
	}
	_, err = s.db.Exec(`UPDATE meta SET data=? WHERE id=1`, b)
	return err
}
func (s *Store) load() (*state, error) {
	v, err := s.loadMeta()
	if err != nil {
		return nil, err
	}
	v.Records = map[uint32]*record{}
	v.Seen = map[string]bool{}
	v.originalRecords = map[uint32]string{}
	v.originalSeen = map[string]bool{}
	rows, err := s.db.Query(`SELECT id,data FROM records`)
	if err != nil {
		return nil, err
	}
	for rows.Next() {
		var id uint32
		var b []byte
		if err = rows.Scan(&id, &b); err != nil {
			rows.Close()
			return nil, err
		}
		var r record
		if err = json.Unmarshal(b, &r); err != nil {
			rows.Close()
			return nil, err
		}
		v.Records[id] = &r
		v.originalRecords[id] = string(b)
	}
	err = rows.Err()
	rows.Close()
	if err != nil {
		return nil, err
	}
	rows, err = s.db.Query(`SELECT id FROM seen`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var id string
		if err = rows.Scan(&id); err != nil {
			return nil, err
		}
		v.Seen[id] = true
		v.originalSeen[id] = true
	}
	return v, rows.Err()
}
func (s *Store) save(v *state) error {
	if v.Records == nil || v.Seen == nil {
		return errors.New("incomplete store transaction")
	}
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	b, err := json.Marshal(v)
	if err != nil {
		return err
	}
	if _, err = tx.Exec(`UPDATE meta SET data=? WHERE id=1`, b); err != nil {
		return err
	}
	for id, r := range v.Records {
		b, err = json.Marshal(r)
		if err != nil {
			return err
		}
		if v.originalRecords[id] == string(b) {
			continue
		}
		if _, err = tx.Exec(`INSERT INTO records(id,data,pending) VALUES(?,?,?) ON CONFLICT(id) DO UPDATE SET data=excluded.data,pending=excluded.pending`, id, b, r.Pending); err != nil {
			return err
		}
	}
	for id := range v.originalRecords {
		if _, ok := v.Records[id]; !ok {
			if _, err = tx.Exec(`DELETE FROM records WHERE id=?`, id); err != nil {
				return err
			}
		}
	}
	for id := range v.Seen {
		if !v.originalSeen[id] {
			if _, err = tx.Exec(`INSERT OR IGNORE INTO seen VALUES(?)`, id); err != nil {
				return err
			}
		}
	}
	for id := range v.originalSeen {
		if !v.Seen[id] {
			if _, err = tx.Exec(`DELETE FROM seen WHERE id=?`, id); err != nil {
				return err
			}
		}
	}
	return tx.Commit()
}
func (s *Store) pendingIDs() ([]uint32, error) {
	rows, err := s.db.Query(`SELECT id FROM records WHERE pending<>'' ORDER BY id`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	ids := []uint32{}
	for rows.Next() {
		var id uint32
		if err = rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, rows.Err()
}
func (s *Store) get(id uint32) (*record, error) {
	var b []byte
	err := s.db.QueryRow(`SELECT data FROM records WHERE id=?`, id).Scan(&b)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	var r record
	err = json.Unmarshal(b, &r)
	return &r, err
}
func (s *Store) put(r *record) error {
	b, err := json.Marshal(r)
	if err != nil {
		return err
	}
	_, err = s.db.Exec(`UPDATE records SET data=?,pending=? WHERE id=?`, b, r.Pending, r.Item.ID)
	return err
}
func (s *Store) pendingCount() (int, error) {
	meta, err := s.loadMeta()
	if err != nil {
		return 0, err
	}
	var n int
	err = s.db.QueryRow(`SELECT count(*) FROM records WHERE pending<>''`).Scan(&n)
	return n + len(meta.Controls), err
}
func (s *state) alloc() (uint32, error) {
	if s.Next == 0 {
		return 0, errors.New("notification ID exhausted")
	}
	id := s.Next
	s.Next++
	return id, nil
}
func (s *state) bySeq(seq string) *record {
	for _, r := range s.Records {
		if r.Item.Seq == seq {
			return r
		}
	}
	return nil
}
