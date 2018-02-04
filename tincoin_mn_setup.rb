#!/usr/bin/env ruby

require 'tty-spinner'

LOG_FILE = '/tmp/tin_mn.log'

print "Please enter your masternode key, which we'll need later: "
mnkey = gets.chomp

spinner = TTY::Spinner.new("[:spinner] :title")
spinner.update(title: "Starting install...")
spinner.auto_spin

def wait_for_process(text, find: nil, nowait: false)
  File.open(LOG_FILE, 'a+') { |f| f.write("Now going to run #{text}") }
  proc = IO.popen(text, err: [:child, :out])
  Process.waitpid2(proc.pid) unless nowait
  return proc.read =~ /#{find}/ unless find.nil?

  File.open(LOG_FILE, 'a+') { |f| f.write(proc.read) }
end

spinner.update(title: "Installing base dependencies...")

wait_for_process("sudo apt-get update")
wait_for_process("sudo apt-get install -y git")
wait_for_process("git clone https://github.com/tincoinpay/tincoin.git")
wait_for_process("sudo apt-get install -y build-essential libtool autotools-dev automake pkg-config libssl-dev libevent-dev bsdmainutils libboost-system-dev libboost-filesystem-dev libboost-chrono-dev libboost-program-options-dev libboost-test-dev libboost-thread-dev")
wait_for_process("sudo add-apt-repository -yu ppa:bitcoin/bitcoin")

# For some reason waiting here stalls forever. Not sure what's up, but we don't
# need to wait on the install here, as it'll take a bit to make swap/set up the
# configuration before the make step starts
wait_for_process("sudo apt-get install -y libdb4.8-dev libdb4.8++-dev libqt5gui5 libqt5core5a libqt5dbus5 qttools5-dev qttools5-dev-tools libprotobuf-dev protobuf-compiler libminiupnpc-dev libzmq3-dev libqrencode-dev", nowait: true)

spinner.update(title: "Making swap...")

wait_for_process("sudo fallocate -l 4G /mnt/4GB.swap && sudo mkswap /mnt/4GB.swap && sudo swapon /mnt/4GB.swap && echo '/mnt/4GB.swap  none  swap  sw 0  0' >> /etc/fstab && sudo swapon -s")

spinner.update(title: "Building tincoin source, this could take a while...")

wait_for_process("cd ~/tincoin &&  ./autogen.sh && ./configure && make && make install")

spinner.update(title: "Okay, tincoin has now been installed! Setting up config...")

sleep(5)

ip = %x(hostname -I|cut -f1 -d ' ').chomp

# We do this to create all the config files
wait_for_process("mkdir -p ~/.tincoincore")


# Setup config
File.open(Dir.home + "/.tincoincore/tincoin.conf", 'w') do |f|
f.write("rpcuser=#{%x(openssl rand -hex 20).chomp}
rpcpassword=#{%x(openssl rand -hex 20).chomp}
rpcallowip=127.0.0.1
listen=1
server=1
daemon=1
logtimestamps=1
maxconnections=256
masternode=1
masternodeprivkey=#{mnkey}
externalip=#{ip}
bind=#{ip}:9859
")
end

spinner.update(title: "Please update your local wallet config. Your ip is #{ip} ...")

# Loop on trying to start mn; continue on success

wait_for_process("tincoind -daemon", nowait: true)

until wait_for_process("tincoin-cli masternode start local false; tincoin-cli masternode status", find: "Masternode successfully started")
  sleep 10
end

spinner.update(title: "Setting up sentinel...")

# TODO Think this isn't needed, remove if so
# wait_for_process("cd ~/.tincoincore &&  /root/tincoin/src/tincoin-cli stop && rm mncache.dat && rm mnpayments.dat && /root/tincoin/src/tincoind -daemon -reindex")

wait_for_process("sudo apt-get update && sudo apt-get -y install python python-virtualenv && cd ~/ && git clone https://github.com/tincoinpay/sentinel.git ~/sentinel && cd sentinel")

wait_for_process("cd ~/sentinel && virtualenv ./venv && ./venv/bin/pip install -r requirements.txt")

wait_for_process("echo tincoin_conf=/root/.tincoincore/tincoin.conf >> ~/sentinel/sentinel.conf")

spinner.update(title: "Waiting for sync to finish")

until wait_for_process("/root/tincoin/src/tincoin-cli mnsync status", find: "FINISHED")
  sleep 10
end

spinner.update(title: "Finishing up...")

wait_for_process('echo "* * * * * cd /root/sentinel && ./venv/bin/python bin/sentinel.py 2>&1 >> sentinel-cron.log" >> /var/spool/cron/crontabs/root')

wait_for_process("chmod 0600 /var/spool/cron/crontabs/root")

spinner.success("Done!")
