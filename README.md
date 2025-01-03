# cc-email

To get started you need at least 3 advanced computers on the same network (you could also use 2 computers with multishell.run -- 1 for client and 1 for server).

First setup the central auth server by running the following:

```
> pastebin run SbSdvnZN server
> auth_server
```

Then setup the email server with:

```
> pastebin run SbSdvnZN client
> cd ..
> pastebin run LSdUFXvx server
> email_server
```

Then set the chunk to forceload.

Now to setup any clients do:

```
> pastebin run SbSdvnZN client
> cd ..
> pastebin run LSdUFXvx client
```

Then you from the email directory can run the email client with:

```
> email_client
```

and send/receive emails with ease.

The system is event driven so there shouldn't be lots of rednet spam, and the default domain is @tuah since that's what my server uses, but you can configure that in the auth_shared and email_shared files on clients and hosts.

It auto fetches the latest changes from github so if you do modify the domain you'll need to redo that config every time it updates.

There's still some work to do like adding a way to get a list of existing email addresses and adding a gui option to configure the domain, but otherwise it works fine.

Some images:

Login screen: https://imgur.com/a/YHJQfTr

Inbox: https://imgur.com/a/b5hgeWT

Sending email: https://imgur.com/a/DupgX8b
