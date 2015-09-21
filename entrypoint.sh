#!/bin/bash

: ${SSH_USERNAME:=backup}
: ${SSH_USERPASS:=$(dd if=/dev/urandom bs=1 count=15 | base64)}
: ${SSH_KEY_TYPES:="rsa ecdsa ed25119"}

__create_rundir() {
	mkdir -p /var/run/sshd
}

__create_default_user() {
# Create a user to SSH into as.
useradd $SSH_USERNAME
echo -e "$SSH_USERPASS\n$SSH_USERPASS" | (passwd --stdin $SSH_USERNAME)
echo ssh user password: $SSH_USERPASS
}

__create_other_users() {
	USERS=/run/metadata/users
	if [ -f $USERS ]; then
		while read username userpass; do
			[ "$username" ] || continue
			useradd $username
			if [ "$userpass" ] && [ "$userpass" != "-" ]; then
				echo -e "$SSH_USERPASS\n$SSH_USERPASS" |
					passwd --stdin $SSH_USERNAME
			fi

			userhome=$(getent passwd $username | cut -d: -f6)
			install -m 700 -o $username -g $username \
				-d "$userhome/.ssh"

			if [ -f /run/metadata/$username.key ]; then
				install -m 600 -o $username -g $username \
					/run/metadata/$username.key \
					"$userhome/.ssh/authorized_keys"
			fi

			if [ -n "$BACKUPROOT" ]; then
				install -m 700 -o $username -g $username \
					-d $BACKUPROOT/$username
			fi
		done < $USERS
	fi
}

__create_hostkeys() {
	for type in $SSH_KEY_TYPES; do
		k="ssh_host_${type}_key"
		if [ -f /run/metadata/$k ]; then
			install -m 600 /run/metadata/$k /etc/ssh/$k
		else
			echo "generating $type key"
			ssh-keygen -t $type -f /etc/ssh/ssh_host_${type}_key -N ''
		fi
	done
}

# Call all functions
__create_rundir
__create_hostkeys
__create_default_user
__create_other_users

exec "$@"

