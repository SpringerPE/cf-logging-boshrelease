# import dependencies
import os
import sys
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
	sys.stdout.write("writing to stdout\n")
	sys.stdout.flush()
	return "Done writing to stdout"

@app.route("/stderr")
def stderr():
	sys.stderr.write("writing to error\n")
	sys.stderr.flush()
	return "Done writing to stderr"

# start the app
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=port)


