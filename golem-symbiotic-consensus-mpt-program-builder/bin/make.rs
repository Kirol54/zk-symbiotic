#[allow(unused_imports)]
use std::{env, fs};
use sp1_build::{build_program_with_args, BuildArgs};
use sp1_sdk::{HashableKey, ProverClient};

fn main() {
    // Determine the current project directory (where Cargo.toml is located)
    let project_dir = env::current_dir().expect("Failed to get current directory");
    let cargo_dir = project_dir.parent().expect("Failed to find project root directory");

    // Use the correct relative paths based on the project root
    let golem_symbiotic_program_path = cargo_dir.join("golem-symbiotic-consensus-mpt-program");
    let golem_symbiotic_elf_dir = cargo_dir.join("golem-symbiotic-consensus-mpt-program-elf");

    println!("Calling build with args");
    println!("{:?}",golem_symbiotic_program_path.to_str());
    println!("{:?}",golem_symbiotic_elf_dir.to_str());
    // Build the program using the relative paths
    build_program_with_args(
        golem_symbiotic_program_path.to_str().expect("Invalid path"),
        BuildArgs {
            docker: true,
            tag: "v5.0.0".to_string(),
            output_directory: Some(golem_symbiotic_elf_dir.to_str().expect("Invalid path").to_string()),
            ..Default::default()
        },
    );

    println!("ZK built.");
}
