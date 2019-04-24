/*
 Copyright (c) 2012-2015, Pierre-Olivier Latour
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 * The name of Pierre-Olivier Latour may not be used to endorse
 or promote products derived from this software without specific
 prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL PIERRE-OLIVIER LATOUR BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

// http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html
// http://www.iana.org/assignments/http-status-codes/http-status-codes.xhtml

#import <Foundation/Foundation.h>

/**
 *  Convenience constants for "informational" HTTP status codes.
 */
typedef NS_ENUM(NSInteger, CyDWebServerInformationalHTTPStatusCode) {
  kCyDWebServerHTTPStatusCode_Continue = 100,
  kCyDWebServerHTTPStatusCode_SwitchingProtocols = 101,
  kCyDWebServerHTTPStatusCode_Processing = 102
};

/**
 *  Convenience constants for "successful" HTTP status codes.
 */
typedef NS_ENUM(NSInteger, CyDWebServerSuccessfulHTTPStatusCode) {
  kCyDWebServerHTTPStatusCode_OK = 200,
  kCyDWebServerHTTPStatusCode_Created = 201,
  kCyDWebServerHTTPStatusCode_Accepted = 202,
  kCyDWebServerHTTPStatusCode_NonAuthoritativeInformation = 203,
  kCyDWebServerHTTPStatusCode_NoContent = 204,
  kCyDWebServerHTTPStatusCode_ResetContent = 205,
  kCyDWebServerHTTPStatusCode_PartialContent = 206,
  kCyDWebServerHTTPStatusCode_MultiStatus = 207,
  kCyDWebServerHTTPStatusCode_AlreadyReported = 208
};

/**
 *  Convenience constants for "redirection" HTTP status codes.
 */
typedef NS_ENUM(NSInteger, CyDWebServerRedirectionHTTPStatusCode) {
  kCyDWebServerHTTPStatusCode_MultipleChoices = 300,
  kCyDWebServerHTTPStatusCode_MovedPermanently = 301,
  kCyDWebServerHTTPStatusCode_Found = 302,
  kCyDWebServerHTTPStatusCode_SeeOther = 303,
  kCyDWebServerHTTPStatusCode_NotModified = 304,
  kCyDWebServerHTTPStatusCode_UseProxy = 305,
  kCyDWebServerHTTPStatusCode_TemporaryRedirect = 307,
  kCyDWebServerHTTPStatusCode_PermanentRedirect = 308
};

/**
 *  Convenience constants for "client error" HTTP status codes.
 */
typedef NS_ENUM(NSInteger, CyDWebServerClientErrorHTTPStatusCode) {
  kCyDWebServerHTTPStatusCode_BadRequest = 400,
  kCyDWebServerHTTPStatusCode_Unauthorized = 401,
  kCyDWebServerHTTPStatusCode_PaymentRequired = 402,
  kCyDWebServerHTTPStatusCode_Forbidden = 403,
  kCyDWebServerHTTPStatusCode_NotFound = 404,
  kCyDWebServerHTTPStatusCode_MethodNotAllowed = 405,
  kCyDWebServerHTTPStatusCode_NotAcceptable = 406,
  kCyDWebServerHTTPStatusCode_ProxyAuthenticationRequired = 407,
  kCyDWebServerHTTPStatusCode_RequestTimeout = 408,
  kCyDWebServerHTTPStatusCode_Conflict = 409,
  kCyDWebServerHTTPStatusCode_Gone = 410,
  kCyDWebServerHTTPStatusCode_LengthRequired = 411,
  kCyDWebServerHTTPStatusCode_PreconditionFailed = 412,
  kCyDWebServerHTTPStatusCode_RequestEntityTooLarge = 413,
  kCyDWebServerHTTPStatusCode_RequestURITooLong = 414,
  kCyDWebServerHTTPStatusCode_UnsupportedMediaType = 415,
  kCyDWebServerHTTPStatusCode_RequestedRangeNotSatisfiable = 416,
  kCyDWebServerHTTPStatusCode_ExpectationFailed = 417,
  kCyDWebServerHTTPStatusCode_UnprocessableEntity = 422,
  kCyDWebServerHTTPStatusCode_Locked = 423,
  kCyDWebServerHTTPStatusCode_FailedDependency = 424,
  kCyDWebServerHTTPStatusCode_UpgradeRequired = 426,
  kCyDWebServerHTTPStatusCode_PreconditionRequired = 428,
  kCyDWebServerHTTPStatusCode_TooManyRequests = 429,
  kCyDWebServerHTTPStatusCode_RequestHeaderFieldsTooLarge = 431
};

/**
 *  Convenience constants for "server error" HTTP status codes.
 */
typedef NS_ENUM(NSInteger, CyDWebServerServerErrorHTTPStatusCode) {
  kCyDWebServerHTTPStatusCode_InternalServerError = 500,
  kCyDWebServerHTTPStatusCode_NotImplemented = 501,
  kCyDWebServerHTTPStatusCode_BadGateway = 502,
  kCyDWebServerHTTPStatusCode_ServiceUnavailable = 503,
  kCyDWebServerHTTPStatusCode_GatewayTimeout = 504,
  kCyDWebServerHTTPStatusCode_HTTPVersionNotSupported = 505,
  kCyDWebServerHTTPStatusCode_InsufficientStorage = 507,
  kCyDWebServerHTTPStatusCode_LoopDetected = 508,
  kCyDWebServerHTTPStatusCode_NotExtended = 510,
  kCyDWebServerHTTPStatusCode_NetworkAuthenticationRequired = 511
};
