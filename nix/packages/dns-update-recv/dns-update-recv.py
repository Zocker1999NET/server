#!/usr/bin/env python3

from argparse import ArgumentParser

from dnslib.dns import DNSRecord, DNSQuestion
from dnslib.server import BaseResolver


class ShellTrigger(BaseResolver):

    def resolve(self, request: DNSRecord, handler):
        if request.header.opcode != 4:  # opcode NOTIFY
            reply = request.reply(aa=0, ra=0)
            reply.header.rcode = 4  # unsupported kind of query
            return reply
        if len(request.questions) != 1 or request.q.qtype != 6:  # RR SOA
            reply = request.reply(aa=0, ra=0)
            reply.header.rcode = 1  # format error
            return reply
        q: DNSQuestion = request.q
        return request.reply(aa=1, ra=0)


def main():
    parser = ArgumentParser()
    parser.add_argument("--")
