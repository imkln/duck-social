open Lwt.Syntax

let post_service_url = Sys.getenv "POST_SERVICE_URL"

let trending _ =
  let* response, body =
    Cohttp_lwt_unix.Client.get (Uri.of_string (post_service_url ^ "/posts"))
  in
  if Cohttp.Response.status response <> `OK then
    Dream.respond ~code:502 "Post service unavailable"
  else
    let* body = Cohttp_lwt.Body.to_string body in
    let scores = Hashtbl.create 20 in
    let now = Unix.gettimeofday () in

    Yojson.Safe.from_string body
    |> Yojson.Safe.Util.to_list
    |> List.iter (fun post ->
      let created_at =
        post
        |> Yojson.Safe.Util.member "created_at"
        |> Yojson.Safe.Util.to_string
        |> Ptime.of_rfc3339
      in

      let weight =
        match created_at with
        | Error _ -> 0.
        | Ok (time, _, _) ->
            let age = now -. Ptime.to_float_s time in
            match age with
            | age when age < 3600. -> 1.
            | age when age < 21600. -> 0.75
            | age when age < 86400. -> 0.5
            | age when age < 259200. -> 0.25
            | _ -> 0.
      in

      post
      |> Yojson.Safe.Util.member "hashtags"
      |> Yojson.Safe.Util.to_list
      |> List.iter (fun hashtag ->
        let hashtag = Yojson.Safe.Util.to_string hashtag in
        let score =
          Hashtbl.find_opt scores hashtag
          |> Option.value ~default:0.
        in
        Hashtbl.replace scores hashtag (score +. weight))
    );

    let trending =
      Hashtbl.to_seq scores
      |> List.of_seq
      |> List.sort (fun (_, a) (_, b) -> Float.compare b a)
      |> List.filteri (fun i _ -> i < 5)
      |> List.map (fun (hashtag, _) -> `Assoc [("hashtag", `String hashtag)])
    in

    Dream.json (Yojson.Safe.to_string (`List trending))

let () =
  Dream.run ~interface:"0.0.0.0" ~port:8080 @@
  Dream.router [Dream.get "/trending" trending]
