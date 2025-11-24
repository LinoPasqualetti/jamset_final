--
-- File generato con SQLiteStudio v3.4.17 su lun nov 24 17:02:31 2025
--
-- Codifica del testo utilizzata: System
--
PRAGMA foreign_keys = off;
BEGIN TRANSACTION;

-- Tabella: spartiti
CREATE TABLE IF NOT EXISTS spartiti (
    id_univoco_globale  INTEGER UNIQUE,
    IdBra               TEXT,
    titolo              TEXT,
    autore              TEXT,
    strumento           TEXT,
    volume              TEXT,
    PercRadice          TEXT,
    PercResto           TEXT,
    PrimoLInk           TEXT,
    TipoMulti           TEXT,
    TipoDocu            TEXT,
    ArchivioProvenienza TEXT,
    NumPag              INTEGER,
    NumOrig             INTEGER,
    IdVolume            TEXT,
    IdAutore            TEXT,
    PRIMARY KEY (
        id_univoco_globale AUTOINCREMENT
    )
);


-- Tabella: spartiti_fts
CREATE VIRTUAL TABLE IF NOT EXISTS spartiti_fts USING fts5 (
    titolo,
    autore,
    volume,
    ArchivioProvenienza,
    content = ''spartiti'',
    content_rowid = ''IdBra''
);


-- Tabella: spartiti_fts_config
CREATE TABLE IF NOT EXISTS spartiti_fts_config (
    k  PRIMARY KEY,
    v
)
WITHOUT ROWID;


-- Tabella: spartiti_fts_data
CREATE TABLE IF NOT EXISTS spartiti_fts_data (
    id    INTEGER PRIMARY KEY,
    block BLOB
);


-- Tabella: spartiti_fts_docsize
CREATE TABLE IF NOT EXISTS spartiti_fts_docsize (
    id INTEGER PRIMARY KEY,
    sz BLOB
);


-- Tabella: spartiti_fts_idx
CREATE TABLE IF NOT EXISTS spartiti_fts_idx (
    segid,
    term,
    pgno,
    PRIMARY KEY (
        segid,
        term
    )
)
WITHOUT ROWID;


-- Trigger: spartiti_ad
CREATE TRIGGER IF NOT EXISTS spartiti_ad
                       AFTER DELETE
                          ON spartiti
BEGIN
    INSERT INTO spartiti_fts (
                                 spartiti_fts,
                                 rowid,
                                 titolo,
                                 autore,
                                 volume,
                                 ArchivioProvenienza
                             )
                             VALUES (
                                 'delete',
                                 old.IdBra,
                                 old.titolo,
                                 old.autore,
                                 old.volume,
                                 old.ArchivioProvenienza
                             );
END;


-- Trigger: spartiti_ai
CREATE TRIGGER IF NOT EXISTS spartiti_ai
                       AFTER INSERT
                          ON spartiti
BEGIN
    INSERT INTO spartiti_fts (
                                 rowid,
                                 titolo,
                                 autore,
                                 volume,
                                 ArchivioProvenienza
                             )
                             VALUES (
                                 new.IdBra,
                                 new.titolo,
                                 new.autore,
                                 new.volume,
                                 new.ArchivioProvenienza
                             );
END;


-- Trigger: spartiti_au
CREATE TRIGGER IF NOT EXISTS spartiti_au
                       AFTER UPDATE
                          ON spartiti
BEGIN
    INSERT INTO spartiti_fts (
                                 spartiti_fts,
                                 rowid,
                                 titolo,
                                 autore,
                                 volume,
                                 ArchivioProvenienza
                             )
                             VALUES (
                                 'delete',
                                 old.IdBra,
                                 old.titolo,
                                 old.autore,
                                 old.volume,
                                 old.ArchivioProvenienza
                             );
    INSERT INTO spartiti_fts (
                                 rowid,
                                 titolo,
                                 autore,
                                 volume,
                                 ArchivioProvenienza
                             )
                             VALUES (
                                 new.IdBra,
                                 new.titolo,
                                 new.autore,
                                 new.volume,
                                 new.ArchivioProvenienza
                             );
END;


COMMIT TRANSACTION;
PRAGMA foreign_keys = on;
