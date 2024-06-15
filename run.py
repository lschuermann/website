#! /usr/bin/env python3

import os, sys, time
import tempfile
import unittest.mock
import types
import socket
import _thread as thread
import subprocess
import pyinotify
import asyncio
from http.server import HTTPServer, SimpleHTTPRequestHandler

last_modified = time.time()

# https://stackoverflow.com/a/70120267
async def check_output(*args, **kwargs):
    p = await asyncio.create_subprocess_exec(
        *args,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
        **kwargs,
    )
    stdout_data, stderr_data = await p.communicate()
    if p.returncode == 0:
        return stdout_data

def serve_dir(directory):
    last_modified = time.time()

    class RequestHandler(SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            global last_modified
            self.os_fstat_unpatched = os.fstat
            self.last_modified = last_modified

            return SimpleHTTPRequestHandler.__init__(
                self, *args, directory=directory, **kwargs)

        def fake_fstat(self, fileno):
            class StatResultWrapper:
                def __init__(self, base, override_mtime):
                    self.base = base
                    self.override_mtime = override_mtime

                def __getattr__(self, name):
                    if name == "st_mtime":
                        return self.override_mtime
                    else:
                        return getattr(self.base, name)

                def __getitem__(self, key):
                    return self.base[key]

            return StatResultWrapper(
                self.os_fstat_unpatched(fileno),
                self.last_modified,
            )

        # @unittest.mock.patch('os.fstat', side_effect=fake_fstat)
        def send_head(self, *args, **kwargs):
            with unittest.mock.patch('os.fstat', side_effect=self.fake_fstat):
                return SimpleHTTPRequestHandler.send_head(self, *args, **kwargs)

        # Avoid propagating socket errors, such as when the client closes
        # the connection prematurely.
        def handle(self):
            try:
                SimpleHTTPRequestHandler.handle(self)
            except socket.error:
                pass


    httpd = HTTPServer(('localhost', 8080), RequestHandler)

    httpd.serve_forever()


async def serve():
    global last_modified

    with tempfile.TemporaryDirectory() as tmpdir:
        resultdir = tmpdir + "/result"
        print("Build dir:", resultdir)
        thread.start_new_thread(serve_dir, (resultdir, ))

        build_event = asyncio.Event()
        build_event.set()

        class EventProcessor(pyinotify.ProcessEvent):
            _methods = ["IN_CREATE",
                        "IN_CLOSE_WRITE",
                        "IN_DELETE",
                        "IN_DELETE_SELF",
                        "IN_MODIFY",
                        "IN_MOVE_SELF",
                        "IN_MOVED_FROM",
                        "IN_MOVED_TO",
                        "IN_Q_OVERFLOW",
                        "IN_UNMOUNT"]

        def process_generator(cls, method):
            def _method_name(self, event):
                print("Change detected: {} ({}, {})".format(event.pathname, event.maskname, method))
                build_event.set()
            _method_name.__name__ = "process_{}".format(method)
            setattr(cls, _method_name.__name__, _method_name)

        for method in EventProcessor._methods:
            process_generator(EventProcessor, method)

        def test(param):
            print("Event: ", param)

        watch_manager = pyinotify.WatchManager()
        event_notifier = pyinotify.AsyncioNotifier(watch_manager, asyncio.get_event_loop(), default_proc_fun=EventProcessor())

        watch_manager.add_watch(os.path.abspath("./"), pyinotify.ALL_EVENTS, rec=True, auto_add=True)
        # event_notifier.loop()

        while True:
            # Wait for changes, then kick off a rebuild
            await build_event.wait()
            build_event.clear()

            print("Rebuilding...")
            git_rev = await check_output(*["git", "rev-parse", "--short", "HEAD"])
            build_proc = await asyncio.create_subprocess_exec(
                *["nix-build", "-o", resultdir, "--argstr", "baseUrl", "http://localhost:8080", "--arg", "doCheck", "false", "--arg", "renderBlogDrafts", "true", "--argstr", "gitRev", git_rev, "site.nix"],
                #stdout=sys.stdout,
                #stderr=sys.stderr,
                #shell=False,
            )
            await build_proc.wait()
            last_modified = time.time()
            print(f"Build finished, setting last_modified: {last_modified}!")

def main():
    loop = asyncio.get_event_loop()
    loop.run_until_complete(serve())
    loop.close()
    return 0

if __name__ == "__main__":
    sys.exit(main())
