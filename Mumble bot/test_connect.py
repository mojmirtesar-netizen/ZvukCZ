#!/usr/bin/env python3
"""Minimalni test: pripojeni k Mumble serveru a příjem zvuku po jednotlivych mluvcich."""

import os
import ssl
import sysconfig
import time

_opus_dir = os.path.join(sysconfig.get_paths()["purelib"], "pyogg")
if os.path.isdir(_opus_dir):
    os.add_dll_directory(_opus_dir)
    os.environ["PATH"] = _opus_dir + os.pathsep + os.environ["PATH"]

# pymumble_py3 pouziva ssl.wrap_socket(), ktere Python 3.12+ odstranil -
# nahrada přes moderní SSLContext (knihovna sama uz neni udrzovana).
if not hasattr(ssl, "wrap_socket"):
    def _wrap_socket_compat(sock, keyfile=None, certfile=None, server_side=False,
                             cert_reqs=ssl.CERT_NONE, ssl_version=ssl.PROTOCOL_TLS,
                             ca_certs=None, do_handshake_on_connect=True,
                             suppress_ragged_eofs=True, ciphers=None):
        context = ssl.SSLContext(ssl_version)
        if cert_reqs == ssl.CERT_NONE:
            context.check_hostname = False
        context.verify_mode = cert_reqs
        if certfile:
            context.load_cert_chain(certfile, keyfile)
        if ca_certs:
            context.load_verify_locations(ca_certs)
        if ciphers:
            context.set_ciphers(ciphers)
        return context.wrap_socket(
            sock, server_side=server_side,
            do_handshake_on_connect=do_handshake_on_connect,
            suppress_ragged_eofs=suppress_ragged_eofs,
        )
    ssl.wrap_socket = _wrap_socket_compat

import pymumble_py3
from pymumble_py3.constants import PYMUMBLE_CLBK_SOUNDRECEIVED

HERE = os.path.dirname(os.path.abspath(__file__))

HOST = "iron.guildbit.com"
PORT = 50003
PASSWORD = "SmugYuna"
NICK = "ZvukCZ-Bot"
CERT = os.path.join(HERE, "bot_cert.pem")
KEY = os.path.join(HERE, "bot_key.pem")


def on_sound(user, chunk):
    print(f"[zvuk] od {user['name']}: {len(chunk.pcm)} B, {chunk.duration:.3f}s")


mumble = pymumble_py3.Mumble(
    HOST, NICK, port=PORT, password=PASSWORD, certfile=CERT, keyfile=KEY, reconnect=False
)
mumble.callbacks.set_callback(PYMUMBLE_CLBK_SOUNDRECEIVED, on_sound)
mumble.set_receive_sound(True)
mumble.start()
mumble.is_ready()
print(f"Pripojeno jako '{NICK}'. Poslouchám 30 vterin - promluv do Mumble mikrofonu...")
time.sleep(30)
print("Konec testu.")
