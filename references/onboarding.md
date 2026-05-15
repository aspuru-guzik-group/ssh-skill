# Onboarding

Use this when installing the SSH skill on a new group member's machine or when `/ssh` fails because aliases, usernames, keys, or CCDB setup are missing.

## What Each User Needs

Each user needs:

- An Alliance/CCDB username for Narval, Cedar, Killarney, and Trillium.
- A Matter/CSLab username for Mariana and Comte, if they use those local clusters.
- A local SSH keypair.
- The public SSH key registered in CCDB.
- Duo/MFA configured in CCDB for Alliance systems.
- System access activated/agreements accepted in CCDB for the clusters they will use.

## Install

From the skill directory:

```bash
bash scripts/install_ssh_config.sh
```

The script asks for usernames, chooses or creates an SSH key, writes:

```text
~/.config/ssh-skill/env
~/.ssh/config.d/aspuru-guzik-clusters
```

and prints the public key that the user must add to CCDB.

Agents should read `~/.config/ssh-skill/env` when they need the configured usernames. The generated SSH aliases are usually enough for normal use:

```bash
ssh narval
ssh killarney
ssh trillium
ssh mariana
```

## CCDB Checklist

The user should add the printed public key to their CCDB SSH keys / authorized keys page. Then they should confirm:

- MFA is enrolled.
- Required agreements are accepted for each target cluster.
- Their role/renewal is active and sponsor confirmation is complete if CCDB shows it pending.
- Their group allocations include the needed projects/accounts.

After CCDB changes, it can take a little time for keys and access to propagate.

## First Login

Run an interactive first login so Duo can be approved and SSH ControlMaster can create a reusable connection:

```bash
ssh narval
ssh killarney
ssh trillium
```

If Duo offers push options, select the user's device and wait for approval. Do not automate around MFA.

After a successful login, repeated agent commands can usually reuse the control socket:

```bash
ssh -O check narval
ssh narval 'bash -lc "hostname; whoami"'
```

## Troubleshooting

If public-key auth fails:

```bash
ssh -v <cluster>
```

Check that:

- The alias points to the right user.
- `IdentityFile` points to the key whose public key was added in CCDB.
- The public key is visible in CCDB.
- The cluster is enabled for the user in CCDB.

If the error is `Permission denied (keyboard-interactive)`, the key likely worked and the remaining blocker is MFA, system access activation, or an Alliance account state.

If the error is `Permission denied (publickey)`, the cluster did not accept the key.
