---
name: Bug report
about: Something isn't working as expected
title: "[BUG] "
labels: bug
assignees: ''
---

## Description

What happened and what did you expect to happen.

## Environment

- OS:
- n8n version:
- Podman version: `podman --version`
- Deployment method: SaltStack `install.sh`

## Steps to reproduce

1.
2.
3.

## Relevant logs

```
podman logs <container>
# or
salt-call --local state.apply -l debug
```

## Additional context

Any other details.
