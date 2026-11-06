// TNK Remoto: dentro da rede da TNK usa o IP local do servidor; fora dela, o endereco publico
// (RENDEZVOUS_SERVERS). Assim nao depende do roteador fazer NAT loopback.
// SERVIDOR_LOCAL e gravado por tnk/aplicar-marca.sh; vazio desliga este recurso.
use hbb_common::{
    config::{PROD_RENDEZVOUS_SERVER, RENDEZVOUS_PORT, RENDEZVOUS_SERVERS},
    log,
};
use std::{
    net::{TcpStream, ToSocketAddrs},
    time::Duration,
};

pub const SERVIDOR_LOCAL: &str = "10.1.1.106";
const INTERVALO: Duration = Duration::from_secs(30);
const TIMEOUT: Duration = Duration::from_millis(800);

pub fn start() {
    let Some(publico) = RENDEZVOUS_SERVERS.first().copied() else {
        return;
    };
    if SERVIDOR_LOCAL.is_empty() {
        return;
    }
    *PROD_RENDEZVOUS_SERVER.write().unwrap() = publico.to_owned();
    std::thread::spawn(move || loop {
        let escolhido = if local_responde() {
            SERVIDOR_LOCAL
        } else {
            publico
        };
        let mudou = {
            let mut atual = PROD_RENDEZVOUS_SERVER.write().unwrap();
            if *atual != escolhido {
                *atual = escolhido.to_owned();
                true
            } else {
                false
            }
        };
        if mudou {
            log::info!("TNK: servidor {escolhido}");
            crate::RendezvousMediator::restart();
        }
        std::thread::sleep(INTERVALO);
    });
}

fn local_responde() -> bool {
    crate::check_port(SERVIDOR_LOCAL, RENDEZVOUS_PORT)
        .to_socket_addrs()
        .ok()
        .and_then(|mut addrs| addrs.next())
        .map_or(false, |addr| TcpStream::connect_timeout(&addr, TIMEOUT).is_ok())
}

// O hbbs anuncia o relay pelo endereco publico; dentro da rede troca pelo IP local.
pub fn relay_local(relay: String) -> String {
    if SERVIDOR_LOCAL.is_empty() || *PROD_RENDEZVOUS_SERVER.read().unwrap() != SERVIDOR_LOCAL {
        return relay;
    }
    let Some(publico) = RENDEZVOUS_SERVERS.first() else {
        return relay;
    };
    match relay.rsplit_once(':') {
        Some((host, porta)) if host.eq_ignore_ascii_case(publico) => {
            format!("{SERVIDOR_LOCAL}:{porta}")
        }
        _ => relay,
    }
}
