# system-health-fedora
Simple Bash Script for Monitoring Fedora Health


chmod +rwx check.sh
```
sudo ./check.sh
```
or
```
sudo script -q -c "./check.sh" output.log

aha < output.log > output.html

wkhtmltopdf --enable-local-file-access output.html check.pdf
```
