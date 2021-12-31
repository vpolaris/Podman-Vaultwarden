#!/usr/bin/env python3
#Backup based on weekly pattern, suffixed by the day of the week  0 ==> Monday, to 6==> Sunday
#You need to setup environnment variable DB_BACKUP with following values to set operation mode
#disabled : the backup operation is deactivated
#enabled : the backup operation is activated
#maintener : szfd9g@live.fr

import sqlite3
import io
import os, sys, shutil, gzip
from datetime import datetime

status = os.getenv('DB_BACKUP')
if status=='disabled':
    print('DB Backup is disabled ')
    sys.exit(0)

if status=='enabled':    
    myday=(datetime.today().weekday())


    filename='/var/lib/vaultwarden/backup/database_dump-'+str(myday)

    if os.path.exists(filename+".gz"):
        os.remove(filename+".gz")

    #https://www.geeksforgeeks.org/how-to-create-a-backup-of-a-sqlite-database-using-python/
    conn = sqlite3.connect('/var/lib/vaultwarden/data/db.sqlite3')
    with io.open(filename+'.sql', 'w') as p:
        for line in conn.iterdump():
            p.write('%s\n' % line)
    p.close
    conn.close()

    #https://towardsdatascience.com/all-the-ways-to-compress-and-archive-files-in-python-e8076ccedb4b

    with open(filename+'.sql', "rb") as fin, gzip.open(f''+filename+'.gz', "wb") as fout:
        # Reads the file by chunks to avoid exhausting memory
        shutil.copyfileobj(fin, fout)
        
    if os.path.exists(filename+".sql"):
        os.remove(filename+".sql")
      
    print('Backup performed successfully!')

else:
    print('unable to understand what you mean!')
    print('valid options are: enabled or disabled')
    sys.exit(1)