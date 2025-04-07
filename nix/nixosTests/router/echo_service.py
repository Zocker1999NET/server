#!/usr/bin/env python3

from __future__ import annotations

import argparse
from http.server import (
    BaseHTTPRequestHandler,
    HTTPServer,
)
from ipaddress import IPv6Address
from socket import AF_INET6


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("-b", "--bind", type=str, default="")
    parser.add_argument("-p", "--port", type=int, default=8080)
    args = parser.parse_args()
    print(f"start HTTP address echo service at {args.bind or '*'}:{args.port}")
    port = EchoHTTPServer((args.bind, args.port), EchoRequestHandler)
    port.serve_forever()


class EchoHTTPServer(HTTPServer):
    address_family = AF_INET6


class EchoRequestHandler(BaseHTTPRequestHandler):

    def do_GET(self):
        addr, port, flowinfo, scope_id = self.client_address
        ip_addr = IPv6Address(addr)
        real_addr = str(ip_addr.ipv4_mapped or addr)
        self.send_response(200)
        self.send_header("content-type", "text/html")
        self.end_headers()
        self.wfile.write(real_addr.encode())


if __name__ == "__main__":
    main()
