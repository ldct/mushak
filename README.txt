

	M     M                 h           k
	MM   MM                 h           k
	M M M M  oo   oo   sss  h hh   aaa  k  k         
	M  M  M o  o o  o s     hh  h     a k k     
	M     M o  o o  o  sss  h   h  aaaa kk      
	M     M o  o o  o     s h   h a   a k k     
	M     M  oo   oo   sss  h   h  aaaa k  k    


1) Introdution
--------------
Moosak is a web-based system for managing programming contests with
automatic judging. It manages program submissions, teams questions and
printouts.  


2) Requirements
---------------
To install Mooshak you must have a Linux server with the following
packages installed 

	 *) Tcl 8.3 or greater
	 *) Apache 1.2 or greater

3) Installation
---------------
After unpacking the content of this directory execute the install
script as root

      % tar xvzf mooshak.tgz
      % cd mooshak
      % su
      # ./install

The installation script creates an user named 'mooshak' with a
'public_html' directory  with all data, CGI scrits and Apache
configuration files. You can control this script with the following options:

	--user	<username>	specify a user name; default is mooshak
	--directory <dir>	home directory; default given by useradd(1)
	--hostname <host>	hostname; defaults to servers hostname
	--source <source>	specify source archive; default is ./source.tgz
	--data <data>		specify data archive; default is ./data.tgz

	--install		installs mooshak; default action
	--update		does not alter data, just code
	--uninstall		removes mooshak instalation in that user


If you later decide to remove the Mooshak installation you can execute
the install script with the --uninstall flag. This will remove all the
Mooshak files and the Mooshak user. Be carefull.

If you have already a Mooshak installation in the user directory you specified
then the install script will prevent installation to avoid damaging your data.
You can:

    * install under a different user name using the --user flag
    * remove the current instalation in that user with the --uninstall flag
    * update the source code, mantaining the data, with the --update flag


4) Running
----------
To start using Mooshak just open your favorite browser with the URL

     http://your.machine/~mooshak 

(assuming you used the Mooshak default user; othewise change the user
name to the one you have choosen).

In this page you will find links to several system views such as
contestant, administrador and audience. The access to the first two
views requires an authentication. After installing Mooshak there will
be a running contest named 'Test' and you will be able to access the
contestant view with:

	   Id:		team
	   Password:	team

and access the administration view with

	   Id:		admin
	   Password:	admin

Using the admin interface you will be able to create new users and
passwords.


5) Troubleshooting
------------------
Some problems you may run into when trying to install Mooshak


* I get a server error after accessing Mooshak's initial page

This probably means that your Apache configuration does not support a
/cgi-bin/ directory for users. To allow programs to be executed in
this directory you should include these lines in the Apache
configuration file e restart the server. 

<Directory /home/*/public_html/cgi-bin>
     Options +ExecCGI -Includes -Indexes
     SetHandler cgi-script
</Directory>


* When I use the save command in the admin's screen I get an error message

Mooshak's scripts and data files are installed in a certain OS
user's home - by default mooshak - and the CGI scripts should run
with the same user. The suexec module of Apache runs
CGI scripts in users directories as the corresponding and ensures that
scripts cannot be invoked by other users. Mooshak expects
suexec in order to run properly.

If you have this kind of error then you probably don't have
suexec installed. Some distributions install
suexec by default when you install Apache. Sometimes you
may need to recompile Apache with a certain configuration


Of course that you can just give all permissions to all data files by
executing chmod -R 777 data command in Mooshak's home
directory but I advise you against it. You will be compromising your
contest security. 

* Probably the suexec module is not installed

Mooshak requires Apache's suexec to work properly. Briefly, suexec
provides Apache users the ability to run CGI and SSI programs under 
user IDs different from the user ID of the calling web-server.

In some Linux distributions, such as those derived from Debian, suexec
is not enabled by default. If you're distribution is

	Debian
	Ubuntu
	Kubuntu
	Edubuntu

and the installer says you might want to try "install --config-suxec",
this is what you should know. When --config-suexec is invoked the 
installer checks if suexec module is available. If it's available the 
script just enables it and restarts apache.

Until now, the only way know to us to reconfigure Apache to 
support suexec is by doing the following:

root> dpkg-reconfigure -plow apache2
or
root> dpkg-reconfigure -plow apache

and then say yes when it asks for suexec support. Since this procedure
invokes an interface outside the installer we decided not to include it.
But if you get the error "Apache not compiled with suexec - module not found"
you may want to run these previous commands and then redo the install
with --config-suexec option.

Note: --config-suexec is a standalone option, it shouldn't be called
along with any other options.


6) Directory structure
-----------------------

Mooshak is installed in a user home directory and several
sub-directories are automatically created:


	data		data of all contests
	public_html	CGIs and static html (help pages)
	packages	Tcl packages used by CGIs
	templates	HTML templates for CGIs
	binaries	programs required by Mooshak
	contrib		other files contributed by different people	

Under each of these directories you will find a README.txt file
with more information on their content


7) Credits
-------------


Thanks to:

 * Pedro Pereira (c0207059@alunos.dcc.fc.up.pt)
     for the reimplementation of the safe execution environment
 * Vitor Monteiro (bitoiu.cc@clix.pt) 
     for fixing the installer for Debian distributions 
 * Ginés García Mateos (ginesgm@um.es) 
     for the translation to Spanish
 * Nohit Nanda (mohit.nanda@tcs.com)
     for improvements in the safe execution environment
 * Robert R. Enderlein (mooshak@hc2.ch)
     for an improved version of the data replication script
