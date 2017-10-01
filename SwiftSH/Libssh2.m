//
// The MIT License (MIT)
//
// Copyright (c) 2017 Tommaso Madonia
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

#import "Libssh2.h"

@import Darwin;
@import Libssh2;
@import Foundation;

void trace_callback(LIBSSH2_SESSION *session, void *context, const char *data, size_t length) {
    NSLog(@"Trace Callback");
}

ssize_t send_callback(libssh2_socket_t socket, const void *buffer, size_t length, int flags, void **abstract) {
    ssize_t returnCode = send(socket, buffer, length, flags);
    
    if (returnCode < 0) {
        return -errno;
    } else {
        return returnCode;
    }
}

ssize_t receive_callback(libssh2_socket_t socket, void *buffer, size_t length, int flags, void **abstract) {
    ssize_t returnCode = recv(socket, buffer, length, flags);
    
    if (returnCode >= 0) {
        return returnCode;
    } else if (errno == ENOENT) {
        return -EAGAIN;
    } else {
        return -errno;
    }
}

void disconnect_callback(LIBSSH2_SESSION *session, int reason, const char *message, int message_length, const char *language, int language_length, void **abstract) {
    NSLog(@"Libssh2 disconnect");
}

void libssh2_setup_session_callbacks(void *session) {
    libssh2_trace(session, 1);
    libssh2_trace_sethandler(session, nil, &trace_callback);
    
    libssh2_session_callback_set(session, LIBSSH2_CALLBACK_SEND, &send_callback);
    libssh2_session_callback_set(session, LIBSSH2_CALLBACK_RECV, &receive_callback);
    libssh2_session_callback_set(session, LIBSSH2_CALLBACK_DISCONNECT, &disconnect_callback);
}
