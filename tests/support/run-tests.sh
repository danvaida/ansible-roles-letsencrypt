#!/bin/bash

set +e

# running in dry-run mode
ansible-playbook test_defaults.yml --diff --check

set -e
ansible-playbook test_defaults.yml

# running a second time to verify playbook's idempotence

ansible-playbook test_defaults.yml > /tmp/second_run.log
{
    tail -n 5 /tmp/second_run.log | grep 'changed=0' &&
    echo 'Playbook is idempotent'
} || {
    cat /tmp/second_run.log
    echo 'Playbook is **NOT** idempotent'
    exit 1
}

set +e

# running in dry-run mode
ansible-playbook test_issuing.yml --diff --check

set -e
ansible-playbook test_issuing.yml

# running a second time to verify playbook's idempotence

ansible-playbook test_issuing.yml > /tmp/second_run.log
{
    tail -n 5 /tmp/second_run.log | grep 'changed=0' &&
    echo 'Playbook is idempotent'
} || {
    cat /tmp/second_run.log
    echo 'Playbook is **NOT** idempotent'
    exit 1
}
