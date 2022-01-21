#!/usr/bin/env python3

import argparse
import sys
import boto3

# Note: requires venv setup by python-setup to be activated

class VS(object):

    def __init__(self):
        parser = argparse.ArgumentParser(
            description='manage virtual servers',
            usage=
'''vs <global_command> [<args>] | <machine_name> <command> [<args>]

Global commands are:
    status  Display the status of all known machines

Machine commands are:
   up       Ensure machine is running (create or start or resume or noop)
   halt     Shutdown but preserve the machine
   destroy  Destroy the machine
   ssh      Connect
   scp      Copy date to or from the machine
   console  Connect or view the console
   status   status of this machine
''')
        parser.add_argument('machine',
            help='Name of machine (or global command)')

        # parse_args defaults to [1:] for args, but you need to
        # exclude the rest of the args too, or validation will fail
        args = parser.parse_args(sys.argv[1:2])
        if hasattr(self, 'global_' + args.machine):
            getattr(self, 'global_' + args.machine)()
        elif hasattr(self, args.command):
            # use dispatch pattern to invoke method with same name
            getattr(self, args.command)()
        else:
            print('Unrecognized command')
            parser.print_help()
            exit(1)

    def global_status(self):
        ec2 = boto3.resource('ec2')
        for inst in ec2.instances.all():
            print(inst.tags, inst.id, inst.instance_type, inst.state["Name"], inst.public_ip_address)

    def up(self, machine_name):
        parser = argparse.ArgumentParser(
            description='Download objects and refs from another repository')
        # NOT prefixing the argument with -- means it's not optional
        parser.add_argument('repository')
        args = parser.parse_args(sys.argv[2:])
        print('Running up, repository=%s' % args.repository)

    def halt(self, machine_name):
        parser = argparse.ArgumentParser(
            description='Download objects and refs from another repository')
        # NOT prefixing the argument with -- means it's not optional
        parser.add_argument('repository')
        args = parser.parse_args(sys.argv[2:])
        print('Running halt, repository=%s' % args.repository)


if __name__ == '__main__':
    VS()
