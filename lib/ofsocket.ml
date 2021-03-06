(*
 * Copyright (c) 2012 Haris Rotsos <cr409@cl.cam.ac.uk>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)
open Net
open Lwt
open Printf
module OP = Ofpacket

exception ReadError

let sp = Printf.sprintf
let pp = Printf.printf
let ep = Printf.eprintf
let cp = pp "%s\n%!"

let resolve t = Lwt.on_success t (fun _ -> ())

let get_new_buffer len = 
  let buf = OS.Io_page.to_cstruct (OS.Io_page.get ()) in 
    Cstruct.sub buf 0 len 

module Socket = struct  
type t = {
  sock: Channel.t;
  data_cache: Cstruct.t ref; 
}

let create_socket sock = 
  { sock; data_cache=ref (get_new_buffer 0);}

let write_buffer t bits =
  let _ = Channel.write_buffer t.sock bits in  
    Channel.flush t.sock
 
let close t = Channel.close t.sock

(*  let cache_size t =
    List.fold_right (
      fun a r -> 
        r + (Cstruct.len a) ) t.data_cache 0*)

let read_data t len = 
(*     Printf.printf "let rec read_data t data_cache %d = \n%!" len;  *)
  match (len, (Cstruct.len !(t.data_cache) ) ) with
    | (0, _) -> return (get_new_buffer 0)
    | (_, 0) -> 
      lwt data = Channel.read_some t.sock in
      let ret = Cstruct.sub data 0 len in 
      let _ = t.data_cache := (Cstruct.shift data len) in 
        return ret
    | (_, l) when (l >= len) -> 
      let ret = !(t.data_cache) in 
      let ret = Cstruct.sub !(t.data_cache) 0 len in
      let _ = t.data_cache := (Cstruct.shift !(t.data_cache) len) in  
        return ret 
    | (_, l) when (l < len) -> 
      let len_rest = len - l in 
      let ret = Cstruct.set_len !(t.data_cache) len in 
      lwt data = Channel.read_some t.sock in
      let _ = Cstruct.blit data 0 ret l len_rest in 
      let _ = t.data_cache := (Cstruct.shift data len_rest) in 
        return (ret)
end
(*
module Unix_socket = struct  
  type t = {
    sock: Lwt_unix.file_descr;
    data_cache: Cstruct.t list ref; 
  }

  let create_socket sock = 
    { sock; data_cache=(ref []);}

  let rec write_buffer t bits =
    let rec write_buffer_inner t bits = function
    | len when len >= (Cstruct.len bits) -> return ()
    | len -> 
        lwt l = Lwt_bytes.write t.sock bits.Cstruct.buffer 
                  (bits.Cstruct.off + len) ((Cstruct.len bits) - len) in
        let _ = 
          if (l = 0) then 
            raise Net.Nettypes.Closed
        in
          write_buffer_inner t bits (len + l)
  in
    try_lwt 
      write_buffer_inner t bits 0 
    with exn -> 
      let _ = printf "[socket] write error: %s\n%!" (Printexc.to_string exn) in 
        raise Net.Nettypes.Closed

  let close t = return (Lwt_unix.shutdown t.sock Lwt_unix.SHUTDOWN_ALL)

  let buf_size ar = 
    List.fold_right (fun a b -> (Cstruct.len a) + b) ar 0
  
  let rec read_data t len = 
    try_lwt 
      match (len, !(t.data_cache)) with
      | (0, _) -> return (Cstruct.create 0 )
      | (_, []) ->
          let p = Cstruct.of_bigarray (OS.Io_page.get ()) in 
          lwt l = Lwt_bytes.read t.sock p.Cstruct.buffer 0 (Cstruct.len p) in
          let _ = if (l = 0) then raise Net.Nettypes.Closed in
          let _ = t.data_cache := [(Cstruct.sub p 0 l)] in 
            read_data t len
      | (_, head::tail) when (buf_size !(t.data_cache)) >= len -> begin
          let ret = Cstruct.of_bigarray (OS.Io_page.get ()) in 
          let ret_len = ref 0 in 
          let rec read_data_inner = function 
            | head::tail when ((!ret_len + (Cstruct.len head)) < len) ->
                let _ = Cstruct.blit head 0 ret !ret_len (Cstruct.len head) in
                    ret_len := !ret_len + (Cstruct.len head);
                    read_data_inner tail
            | head::tail when ((!ret_len + (Cstruct.len head)) = len) -> 
                  let _ = Cstruct.blit head 0 ret !ret_len (Cstruct.len head) in
                    ret_len := !ret_len + (Cstruct.len head);
                    t.data_cache := tail;
                    return ()
            | head::tail when ((!ret_len + (Cstruct.len head)) > len) -> 
                  let len_rest = len - !ret_len in 
                  let _ = Cstruct.blit head 0 ret !ret_len len_rest in
                  let head = Cstruct.shift head len_rest in 
                    ret_len := !ret_len + len_rest;
                    t.data_cache := [head] @ tail; 
                    return ()
            | rest -> 
                  pp "read_data:Invalid state(req_len:%d,read_len:%d,avail_data:%d)\n%!"
                    len !ret_len (List.fold_right (fun a b -> b + (Cstruct.len a)) rest 0);
                  raise ReadError
            in 
            lwt _ = read_data_inner !(t.data_cache) in
            let ret = Cstruct.sub ret 0 len in  
              return (ret)
          end
      | (_, head::tail) when (buf_size !(t.data_cache)) < len -> 
          let p = Cstruct.of_bigarray (OS.Io_page.get ()) in 
          lwt l = Lwt_bytes.read t.sock p.Cstruct.buffer 0 (Cstruct.len p) in 
          let _ = if (l = 0) then raise Net.Nettypes.Closed in
          let _ = t.data_cache := !(t.data_cache) @ [(Cstruct.sub p 0 l)] in 
            read_data t len
      | (_, _) ->
          let _ = Printf.printf "read_data and not match found\n%!" in
            return (Cstruct.create 0 )
    with exn -> 
      let _ = printf "[socket] read error: %s\n%!" (Printexc.to_string exn) in 
        raise Net.Nettypes.Closed

end 
 *)

type conn_type = 
  | Socket of Socket.t
  | Local of OP.t Lwt_stream.t * (OP.t option -> unit) 
(*  | Unix of Unix_socket.t *)

type conn_state = {
  mutable dpid : OP.datapath_id;
  t : conn_type; 
}

let init_socket_conn_state t = 
  {dpid=0L;t=(Socket (Socket.create_socket t));}
let init_local_conn_state input output = 
  {dpid=0L;t=(Local (input, output));}
(*let init_unix_conn_state fd = 
  {dpid=0L;t=(Unix (Unix_socket.create_socket fd));}*)

let read_packet conn =
  match conn.t with
  | Socket t -> 
      lwt hbuf = Channel.read_exactly t.Socket.sock OP.Header.sizeof_ofp_header in  
      let ofh  = OP.Header.parse_header hbuf in
      let dlen = ofh.OP.Header.len - OP.Header.sizeof_ofp_header in 
      lwt dbuf = 
        if (dlen = 0) then 
          return (Cstruct.create 0)
        else
          Channel.read_exactly t.Socket.sock dlen 
      in 
      let ofp  = OP.parse ofh dbuf in
        return ofp
(*  | Unix t -> 
      lwt hbuf = Unix_socket.read_data t OP.Header.sizeof_ofp_header in
      let ofh  = OP.Header.parse_header hbuf in
      let dlen = ofh.OP.Header.len - OP.Header.sizeof_ofp_header in 
      lwt dbuf = Unix_socket.read_data t dlen in 
      let ofp  = OP.parse ofh dbuf in
        return ofp *)
  | Local (input, _) ->
    match_lwt (Lwt_stream.get input) with
    | None -> raise Nettypes.Closed 
    | Some ofp -> return ofp

let send_packet conn ofp =
  match conn.t with
  | Socket t -> 
      let buf = OP.marshal ofp in 
      Socket.write_buffer t buf
(*  | Unix t -> Unix_socket.write_buffer t (OP.marshal ofp) *)
 | Local (_, output) -> return (output (Some ofp ))

let send_data_raw t bits = 
  match t.t with
  | Local _ -> failwith "send_of_data is not supported in Local mode"
(*  | Unix t -> Unix_socket.write_buffer t bits *)
  | Socket t -> Socket.write_buffer t bits 

let close conn = 
  match conn.t with
  | Socket t -> 
      resolve (
        try_lwt
          Socket.close t
        with exn -> 
          return (printf "[socket] close error: %s\n%!" (Printexc.to_string exn))
          ) 
(*  | Unix t -> 
      resolve (
        try_lwt
           Unix_socket.close t
        with exn -> 
          return (printf "[socket] close error: %s\n%!" (Printexc.to_string exn))
          ) *)
  | Local (_, output) -> output None 
 
