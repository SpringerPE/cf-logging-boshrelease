# import dependencies
import os
import sys
import datetime
from flask import Flask

# bootstrap the app
app = Flask(__name__)

# set the port dynamically with a default of 3000 for local development
port = int(os.getenv('PORT', '3000'))

# our base route which just returns a string
@app.route('/')
def hello_world():
    return 'Congratulations! Use /stdout and /stderr endpoints!'

@app.route("/stdout")
def stdout():
	msg="Writing to stdout, %s" % datetime.datetime.now()
	sys.stdout.write(msg + "\n")
	sys.stdout.flush()
	return msg

@app.route("/stderr")
def stderr():
	msg="Writing to stderr, %s" % datetime.datetime.now()
	sys.stderr.write(msg + "\n")
	sys.stderr.flush()
	return msg

# start the app
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=port)

