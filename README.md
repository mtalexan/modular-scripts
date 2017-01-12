Scripts for quick/easy usage in switching between modular and RRSDK repository sandboxes.  

Assumes all modular repository sandboxes are under ~/modular_code_repos and all RRSDK sandboxes are under ~/rrsdk_code_repos
The directory name in that folder is the name of the sandbox.  The repository must be checked out into a subfolder of the name
directory (~/modular_code_repos/base/modular or ~/rrsdk_code_repos/baseNFS/rrsdk/ksi)

Creates files in ~/local/repos/ that can be sourced by a bashrc file to determine the last modular and rrsdk sandboxes configured.


TODO: The functions that are needed in the bashrc to allow basic commands using these scripts need to be moved to their own files and
so they can be kept with this repo but included in the bashrc.
