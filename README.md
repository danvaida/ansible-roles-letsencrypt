# Ansible Let's Encrypt role

Handles the interaction with the [ACME][1] Server of [Let's Encrypt][2].

Once you complete the challenge and obtain the Certificate, you are responsible for setting it up in your web server of choice.

# Requirements

* `openssl`
* Python >= 2.7.9

# Role Variables

* __letsencrypt_certs_dir:__
  Path to work-dir where all CSRs, Keys and Certs will be stored.

* __letsencrypt_account_key_name:__
  Name of the Let's Encrypt account's RSA key.

* __letsencrypt_account_key_size:__
  Size of the Let's Encrypt account's RSA key.

* __letsencrypt_certs_to_generate:__
  List of certs to generate.

  * __account_email:__
    E-mail address that's going to be exchanged with the ACME server. You'll get cert expiration warnings.

  * __account_key:__
    Path to the RSA key file.

  * __acme_directory:__
    Let's Encrypt ACME API endpoint. Uses their Staging by default.

  * __agreement:__
    URI to TOS doc you agree with.

  * __challenge:__
    The accepted challenge type.

  * __csr:__
    Path to the CSR file.

  * __dest:__
    Path to the resulting Certificate file.

  * __remaining_days:__
    Number of days for the cert to be valid.

# Dependencies

N/A

# Example Playbook

In this example, we are requesting a certificate from Let's Encrypt,
although in theory, this Ansible module should be compatible with any
ACME server.

We have three plays:

* create CSR, Key and issue request for certificate release
* complete the challenge (DNS record in Route53 in this case)
* ask to validate the challenge and grant the certificate

    - name: ACME Step 1
      hosts: localhost
      connection: local
      roles:
        - role: letsencrypt
          letsencrypt_certs_dir:         './files/production/certs'
          letsencrypt_account_key_name:  'letsencrypt_account'
          letsencrypt_account_key_size:  2048
          letsencrypt_certs_to_generate:
            - domain: 'your-domain.com'
              key_size: 2048
              account_email: 'info@your-domain.com'
              account_key: "{{ letsencrypt_certs_dir }}/{{ letsencrypt_account_key_name }}.key"
              challenge: 'dns-01'
              csr: "{{ letsencrypt_certs_dir }}/your-domain.com/your.csr"
              dest: "{{ letsencrypt_certs_dir }}/your-domain.com/domain.crt"
              acme_directory: 'https://acme-v01.api.letsencrypt.org/directory'
          tags: letsencrypt

      tasks:
        - name: List of Route53 records to create should be set as fact
          set_fact:
            route53_records_to_add: "{{
              route53_records_to_add | default([]) +
              [{'zone': item.1.domain,
              'record': item.0.challenge_data[item.1.domain]['dns-01']['resource'] + '.' + item.1.domain + '.',
              'ttl': 300,
              'type': 'TXT',
              'value': '\"' + item.0.challenge_data[item.1.domain]['dns-01']['resource_value'] + '\"' }]
              }}"
          with_together:
            - "{{ letsencrypt_acme_step_one }}"
            - "{{ letsencrypt_certs_to_obtain | default([]) }}"
          when: item.1.domain == item.0.item.domain
          tags: route53

    - name: ACME challenge solving (DNS record in Route53)
      hosts: localhost
      connection: local
      roles:
        - role: route53
          tags: route53

    - name: ACME Step 2
      hosts: localhost
      connection: local
      pre_tasks:
        - name: We should wait for the DNS changes to propagate
          pause: minutes=1

      roles:
        - role: letsencrypt
          letsencrypt_acme_step: two
          tags: letsencrypt

Completing other challenge types should be all the same and opaque to this role.

# Testing

The tests are relying on the DNS challenge type and are solving it via
[AWS Route53][3].

If you want to run the tests on the provided docker environment, run the
following commands:

    $ cd /path/to/ansible-roles/letsencrypt
    $ ansible-galaxy install --force -r ./tests/requirements.yml -p ./tests/dependencies
    $ docker build --no-cache -t ansible-roles-test tests/support
    $ docker run --rm -it \
      -v $PWD:/etc/ansible/roles/letsencrypt \
      -v $PWD/tests/dependencies:/etc/ansible/roles/letsencrypt/tests/roles:ro \
      --workdir /etc/ansible/roles/letsencrypt/tests \
      ansible-roles-test

# To-do

* Support other challenge types
* Support other DNS services APIs (i.e. [Cloud DNS][4])
* Integration with some web servers roles (i.e. NGINX, Apache)
* Support renewal.
* Support multiple Ansible versions and Distros.
* Register/transfer a domain in Route53 for testing purposes.

# License

MIT / BSD

# Author Information

Role created by [Dan Vaida][danvaida.com].

# Contributions

This role is brand-new and obviously, there are plenty of improvements that can be made.
See the [ToDo](#to-do) list. Contributions are welcome.

[1]: https://ietf-wg-acme.github.io/acme/
[2]: https://letsencrypt.org
[3]: https://aws.amazon.com/route53/
[4]: https://cloud.google.com/dns/
