use aurum_pentest::{merkle::{leaf_hash, merkle_root}};
use serde::Serialize;
use tiny_http::{Response, Server};

#[derive(Serialize, Default)]
struct Status{ tip_height: u64, mempool_len: usize, state_root_hex: String }

fn main(){
  let height=0u64; let mempool=vec![b"demo-tx-1".to_vec(), b"demo-tx-2".to_vec()];
  let root = merkle_root(&mempool.iter().map(|m| m.as_slice()).collect::<Vec<_>>()).unwrap();
  let status = Status{ tip_height: height, mempool_len: mempool.len(), state_root_hex: hex::encode(root)};
  let server=Server::http("0.0.0.0:8080").expect("bind");
  println!("AURUM node on http://localhost:8080  (GET /status)");
  for request in server.incoming_requests(){
    match (request.method().as_str(), request.url()){
      ("GET","/status")=>{ let body=serde_json::to_string(&status).unwrap(); let resp=Response::from_string(body).with_header("Content-Type: application/json".parse().unwrap()); let _=request.respond(resp); },
      _=>{ let _=request.respond(Response::from_string("Not Found").with_status_code(404)); }
    }
  }
}
