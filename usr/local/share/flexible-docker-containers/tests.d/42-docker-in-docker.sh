#!/bin/bash
# Copyright (c) 2022-2023, AllWorldIT.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.



fdc_test_start docker-in-docker "Client certificate placed in /certs"
if [ ! -e /certs/client/key.pem ]; then
    fdc_test_fail docker-in-docker "Client certificate not present in /certs"
    false
fi
fdc_test_pass docker-in-docker "Client certificate present"

fdc_test_start docker-in-docker "Checking Docker server responds over socket"
if ! docker images; then
	fdc_test_fail docker-in-docker "Docker server not responding correctly over socket"
	false
fi
fdc_test_pass docker-in-docker "Docker server responds over socket"



export DOCKER_HOST=tcp://127.0.0.1:2376
fdc_test_start docker-in-docker "Checking Docker server responds over IPv4"
if ! docker images; then
	fdc_test_fail docker-in-docker "Docker server not responding correctly over IPv4"
	false
fi
fdc_test_pass docker-in-docker "Docker server responds over IPv4"


# Return if we don't have IPv6 support
if [ -z "$(ip -6 route show default)" ]; then
	return
fi


export DOCKER_HOST="tcp://[::1]:2376"
fdc_test_start docker-in-docker "Checking Docker server responds over IPv6"
if ! docker images; then
	fdc_test_fail docker-in-docker "Docker server not responding correctly over IPv6"
	false
fi
fdc_test_pass docker-in-docker "Docker server responds over IPv6"
