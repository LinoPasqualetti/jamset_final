--
-- File generato con SQLiteStudio v3.4.17 su lun nov 24 16:58:14 2025
--
-- Codifica del testo utilizzata: System
--
PRAGMA foreign_keys = off;
BEGIN TRANSACTION;

-- Tabella: DatiSistremaApp
CREATE TABLE IF NOT EXISTS DatiSistremaApp (
    ModoFiles          TEXT    CHECK (ModoFiles IN ('dataSQL', 'CSV') ) 
                               DEFAULT dataSQL,
    SistemaOperativo   TEXT    DEFAULT Windows,
    TipoInterfaccia    TEXT    DEFAULT Nativa,
    PercorsoPdf        TEXT    DEFAULT [C:\JamsetPDF],
    PercorsoApp        TEXT    DEFAULT [C:\DBSpartiti2\jamset],
    Percorsodatabase   TEXT    DEFAULT [C:\DBSpartiti2\jamset\Assets\databases],
    id_catalogo_attivo NUMERIC DEFAULT (2) 
);


-- Tabella: elenco_cataloghi
CREATE TABLE IF NOT EXISTS elenco_cataloghi (
    id                        INTEGER,
    nome_catalogo             TEXT    NOT NULL
                                      UNIQUE,
    nome_file_db              TEXT    NOT NULL
                                      UNIQUE,
    FilesPath                 TEXT,
    AppPath                   TEXT,
    descrizione               TEXT,
    data_creazione            TEXT    DEFAULT (STRFTIME('%Y-%m-%d %H:%M:%S', 'NOW', 'localtime') ),
    data_ultimo_aggiornamento TEXT,
    conteggio_brani           INTEGER DEFAULT 0,
    icona_catalogo            TEXT,
    PRIMARY KEY (
        id AUTOINCREMENT
    )
);


COMMIT TRANSACTION;
PRAGMA foreign_keys = on;
