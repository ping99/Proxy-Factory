#!/usr/bin/env python
# coding: utf-8
import sys
import os
import platform
import subprocess
import Queue
import threading
import re

#The accepted maximum ping time
MAXIMUM_PING_TIME = 200
def worker_func(pingArgs, pending, done):
    try:
        while True:
            # Get the next address to ping.
            address = pending.get_nowait()

            ping = subprocess.Popen(pingArgs + [address],
                stdout = subprocess.PIPE,
                stderr = subprocess.PIPE
            )
            out, error = ping.communicate()

            # Output the result to the 'done' queue.
            done.put((out, error))
    except Queue.Empty:
        # No more addresses.
        pass
    finally:
        # Tell the main thread that a worker is about to terminate.
        done.put(None)

# The number of workers.
NUM_WORKERS = 10

plat = platform.system()
scriptDir = os.path.split(os.path.realpath(__file__))[0]
google_ip = os.path.join(scriptDir, 'google_ip.txt')

# Remove duplicates in google_ip list.
with open(google_ip, "r") as google_ipFile:
    for line in google_ipFile:
        #first get rid of the \n character
        line = line.strip()
        #split to lists
        columns = list(set(line.split("|")))

with open(google_ip, 'w') as outfile:
    for item in columns:
        line = line + "|" +item
    outfile.write(line)
    outfile.flush()
    outfile.close()

# The arguments for the 'ping', excluding the address.
if plat == "Windows":
    pingArgs = ["ping", "-n", "1", "-l", "1", "-w", "100"]
elif plat == "Darwin":
    pingArgs = ["ping", "-c", "3", "-l", "1", "-s", "56", "-W", "1"]
else:
    raise ValueError("Unknown platform")

# The queue of addresses to ping.
pending = Queue.Queue()

# The queue of results.
done = Queue.Queue()

# Create all the workers.
workers = []
for _ in range(NUM_WORKERS):
    workers.append(threading.Thread(target=worker_func, args=(pingArgs, pending, done)))

# Put all the addresses into the 'pending' queue.
with open(google_ip, "r") as google_ipFile:
    for line in google_ipFile:
        #first get rid of the \n character
        line = line.strip()
        #split to lists
        columns = list(set(line.split("|")))
        for item in columns:
            pending.put(item.strip())

# Start all the workers.
for w in workers:
    w.daemon = True
    w.start()

# Print out the results as they arrive.
ipdict = {}
numTerminated = 0
while numTerminated < NUM_WORKERS:
    result = done.get()
    if result is None:
        # A worker is about to terminate.
        numTerminated += 1
    else:
        out = result[0]
        text = out.replace('\r\n', '\n').replace('\r', '\n')
        
        # match ip: [192.168.1.1] (192.168.1.1)
        ip = re.findall(r'(?<=\(|\[)\d+\.\d+\.\d+\.\d+(?=\)|\])', text)
        if plat == "Windows":
            time = re.findall(r'\d+(?=ms$)', text)
        else:
            time = re.findall(r'(?<=\d/)[\d\.]+(?=/)', text)
            

        lost = re.findall(r'\d+(?=%)', text)
        #if there is no time in the result string becase the IP is dead
        if not time:
                print ip[0] + ": Request timeout for icmp"
        else:
            if float(time[0]) > MAXIMUM_PING_TIME:
                print ip[0] + ": Average time > " + str(MAXIMUM_PING_TIME) +"ms"
            else:
                ipdict[ip[0]] = float(time[0])
# Wait for all the workers to terminate.
for w in workers:
    w.join()


if not ipdict:
    print "No good ip!"
    exit()
else:
    ipstring = ""
    for key, value in sorted(ipdict.iteritems(), key=lambda (k,v): (v,k)):
        if ipstring and not ipstring.isspace():
            ipstring = (ipstring + "|" + key)
        else:
            ipstring = key
    print ipstring
    best_ip = min(ipdict, key = lambda x:ipdict[x])

def inplace_change(filename, old_string, new_string):
    lines = []
    with open(filename, "r") as inFile:
        for line in inFile:
            if 'google_cn =' in line:
                line = 'google_cn = ' + ipstring + '\n'
            else:
                if 'google_hk =' in line:
                    line = 'google_hk = ' + ipstring + '\n'
            lines.append(line)
        inFile.close()            
    with open(filename, 'w') as outfile:
        for line in lines:
            outfile.write(line)
            outfile.flush()
    outfile.close()
                
proxy_user_ini = os.path.join(scriptDir, 'proxy.user.ini')

inplace_change(proxy_user_ini, 'not used here', best_ip)

