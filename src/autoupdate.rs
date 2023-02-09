extern crate {tempdir, reqwest, regex}

use std::fs::File;
use std::io::{self, Write};
use tempdir::TempDir;

use reqwest::blocking::Client;
use regex::Regex;

pub impl Updater {
    pub fn new() -> Self {
        Self {
            current_version: VERSION,
            check_every: 3600,
        }
    }

    pub fn update() {
        let body = reqwest::get("https://rd.printax27.ru/api/current_version")
        .await?
        .text()
        .await?;
        println!(body);
        let server_version = body.split_once("\n")[0];
        static ref SV: sv = Regex::new(r"[0-9]+\.[0-9]+\.[0-9]+").unwrap();
        if (not SV.is_match(server_version)) {
            return -1
        }
        let update_url = body.split_once("\n")[1];
        if (server_version > current_version) {
            let dfile = reqwest::get(update_url).await?;
            let tmp_dir = TempDir::new()?;
            let fpath = tmp_dir.path().join("rd.exe");
            let mut tmp_file = File::create(fpath);
            let mut content = Cursor::new(dfile.bytes().await?);
            std::io::copy(&mut content, &mut tmp_file)?;
            tmp_file.close();
            std::process::Command::new(fpath).args(["--silent-install"]).spawn();
        }
    }
}