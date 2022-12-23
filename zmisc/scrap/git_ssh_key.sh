
#!/bin/bash

#ssh-keygen -t ed25519 -C "${email}"
ssh-keygen -t rsa -b 4096 -C "${email}"

# add to .ssh/config

# delete authorized keys

