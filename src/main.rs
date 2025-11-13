use std::process::ExitCode;

use anyhow::Result;
use clap::{Parser, Subcommand};

/// wgx – Heimgewebe Fleet-Orchestrator (Rust-Stub)
///
/// Achtung:
/// Dies ist eine minimal lauffähige CLI-Hülle, damit `cargo install wgx`
/// und CI-Jobs nicht mehr an einem fehlenden Cargo.toml scheitern.
///
/// Die eigentliche Orchestrierungslogik (doctor, smoke, metrics, run …)
/// muss schrittweise aus den bestehenden Shell-Skripten/Profiles
/// nach Rust überführt werden.
#[derive(Parser, Debug)]
#[command(name = "wgx")]
#[command(about = "Heimgewebe Fleet-Orchestrator (Rust-CLI-Stub)", long_about = None)]
struct Cli {
    /// Erhöhte Ausführlichkeit
    #[arg(short, long, global = true)]
    verbose: bool,

    #[command(subcommand)]
    command: Option<Command>,
}

#[derive(Subcommand, Debug)]
enum Command {
    /// Zeige Version und Build-Info
    Version,
    /// Dummy-Command, damit CI `wgx` erfolgreich aufrufen kann
    ///
    /// Beispiel: `wgx noop` → Exit-Code 0, macht nichts kaputt.
    Noop,
}

fn main() -> ExitCode {
    if let Err(err) = real_main() {
        eprintln!("wgx (stub) error: {err:?}");
        return ExitCode::from(1);
    }
    ExitCode::SUCCESS
}

fn real_main() -> Result<()> {
    let cli = Cli::parse();

    if cli.verbose {
        eprintln!("wgx (stub) – verbose mode aktiv");
    }

    match cli.command.unwrap_or(Command::Noop) {
        Command::Version => {
            // Version aus Cargo-Umgebungsvariablen
            let ver = env!("CARGO_PKG_VERSION");
            let name = env!("CARGO_PKG_NAME");
            println!("{name} {ver}");
        }
        Command::Noop => {
            // Wichtig: Exit 0, damit CI-Schritte mit `wgx` nicht mehr hart fehlschlagen.
            eprintln!(
                "wgx (Rust-Stub): keine echte Orchestrierung implementiert.\n\
                 - Für CI: ok, Binary existiert und läuft.\n\
                 - Für echte Fleet-Tasks: weiterhin vorhandene Shell-/WGX-Implementierung nutzen."
            );
        }
    }

    Ok(())
}
