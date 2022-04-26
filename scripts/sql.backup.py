#!/usr/bin/env python3
#Backup based on weekly pattern, suffixed by the day of the week  0 ==> Monday, to 6==> Sunday
#You need to setup environnment variable DB_BACKUP with following values to set operation mode
#disabled : the backup operation is deactivated
#enabled : the backup operation is activated
#maintener : szfd9g@live.fr

import sqlite3
import io
import glob
import os
import sys
import shutil
import tarfile
from datetime import datetime

status = os.getenv('DB_BACKUP')
if status=='disabled':
    print('DB Backup is disabled ')
    sys.exit(0)

# DB_PATH='/var/lib/vaultwarden/data'
DB_PATH='/home/vaultwarden/.persistent_storage/vaultwarden/data'
# BKP_PATH='/var/lib/vaultwarden/backup'
BKP_PATH='/home/vaultwarden/.persistent_storage/vaultwarden/backup'
if status=='enabled':    
    myday=(datetime.today().weekday())


    filename=BKP_PATH+'/database_dump-'+str(myday)
    print(filename+".tar.gz")

    if os.path.exists(filename+".tar.gz"):
        os.remove(filename+".tar.gz")

    #https://www.geeksforgeeks.org/how-to-create-a-backup-of-a-sqlite-database-using-python/
    conn = sqlite3.connect(DB_PATH+'/db.sqlite3')
    with io.open(filename+'.sql', 'w') as p:
        for line in conn.iterdump():
            p.write('%s\n' % line)
    p.close()
    conn.close()
    
    #Get rsa_key files listing_
    bkp_files=[]
    bkp_files.extend(glob.glob(DB_PATH+"/rsa_key*"))
    bkp_files.append(filename+'.sql')
    

    with tarfile.open(filename+'.tar.gz', "x:gz") as fout:
        for file in bkp_files:
            with open(file, "r") as fin:
                # Reads the file by chunks to avoid exhausting memory
                fout.addfile(tarfile.TarInfo(file))
            fin.close()
    fout.close()
        
    if os.path.exists(filename+".sql"):
        os.remove(filename+".sql")
      
    print('Backup performed successfully!')

else:
    print('unable to understand what you mean!')
    print('valid options are: enabled or disabled')
    sys.exit(1)