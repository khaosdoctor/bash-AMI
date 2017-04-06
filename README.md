# bash-AMI

> Bash script to remotely create AWS Machine Images

## Usage

1. Download [the file](https://raw.githubusercontent.com/khaosdoctor/bash-AMI/master/bash-ami.sh)
2. Save it anywhere you want (give it `+x` permissions with `chmod +x bash-ami.sh`)
3. Run like: `./bash-ami.sh` (or save it in `usr/bin` and run it as a common command)

### Commands

```
# AMI remote creation script
-> Options:
     -i    Sets the instance ID which will be the AMI base (Generaly it is "i-<a-bunch-of-numbers>")
     -r    Sets the AWS region this instance resides (e.g: us-east-1, us-east-2)
     -T    Dry run mode (No action is really performed, just the test is executed)
```

Be happy :smile:

MIT © [Lucas Santos](http://lsantos.me)
