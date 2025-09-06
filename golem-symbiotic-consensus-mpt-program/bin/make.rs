#[allow(unused_imports)]
use sp1_build::{build_program_with_args, BuildArgs};
use sp1_sdk::ProverClient;

fn main() {
    build_program_with_args(
        "../",
        BuildArgs {
            docker: true,
            tag: "v4.1.3".to_string(),
            output_directory: Some("../golem-symbiotic-consensus-mpt-program-elf".to_string()),
            ..Default::default()
        },
    );

     /*const ELF: &[u8] = include_bytes!("../../elf/sp1-helios-elf");
     let client = ProverClient::from_env();
     let (pk, vk) = client.setup(ELF);*/

}
