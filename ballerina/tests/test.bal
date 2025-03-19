// Copyright (c) 2025, WSO2 LLC. (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/http;
import ballerina/os;
import ballerina/test;
import ballerina/io;

configurable decimal timeout = 180.0;
configurable string liveServerUrl = "http://localhost:11434/api";
configurable string mockServerUrl = "http://localhost:9090";
configurable boolean isLiveServer = os:getEnv("IS_LIVE_SERVER") == "true";

const string llama3_2 = "llama3.2";
const string mistral = "mistral";
const string deepseek = "deepseek-r1";
const string incorrectModel = "model_xyz";
const string suffix = "Ends your answer with `I am fine.`";
const string prompt = "Hello, how are you?";

GenerateRequest request = {
    model: llama3_2
};

final Client ollama = check initClient();

isolated function initClient() returns Client|error {
    if isLiveServer {
        return check new ({
            timeout: timeout
        }, liveServerUrl);
    }
    return check new ({}, mockServerUrl);
}

@test:Config {
    groups: ["negative_tests", "loading"]
}
function testLoadUnavailableModel() returns error? {
    request = {
        model: incorrectModel
    };
    GenerateStreamResponse|GenerateSingleResponse|error response = ollama->/generate.post(request);
    test:assertTrue(response is http:ClientRequestError, "Error loading unavailable model");
    if response is http:ClientRequestError {
        test:assertEquals(response.detail()["statusCode"], 404, "Invalid status code for unavailable model");
    }
}

@test:Config {
    groups: ["positive_tests", "loading"]
}
function testLoadAvailableModel() returns error? {
    request = {
        model: llama3_2,
        'stream: true
    };
    GenerateStreamResponse|GenerateSingleResponse|error response = ollama->/generate.post(request);
    test:assertTrue(response is GenerateStreamResponse, "Error loading available model");
    if response is GenerateStreamResponse {
        test:assertEquals(response.done, true, "Invalid field value for done");
        test:assertEquals(response?.done_reason ?: "", "load", "Done reason should be load");
        test:assertEquals(response.response, "", "Response should be empty");
    }
}

@test:Config {
    groups: ["positive_tests", "generation", "stream_response"],
    enable: false
}
function testStreamResponse() returns error? {
    request = {
        model: llama3_2,
        prompt: prompt,
        'stream: true
    };
    anydata|GenerateStreamResponse|GenerateSingleResponse|error response = ollama->/generate.post(request);
    io:println("Response: ", response);
    test:assertTrue(response is GenerateStreamResponse, "Error generating stream response");
    if response is GenerateStreamResponse {
        test:assertEquals(response.done, false, "Stream response should not be done for the first chunk");
        test:assertNotEquals(response.response, "", "Response should be empty");
    }
}

@test:Config {
    groups: ["positive_tests", "generation", "single_response"]
}
function testSingleResponse() returns error? {
    request = {
        model: llama3_2,
        prompt: prompt,
        'stream: false
    };
    GenerateStreamResponse|GenerateSingleResponse|error response = ollama->/generate.post(request);
    test:assertTrue(response is GenerateSingleResponse, "Error generating single response");
    if response is GenerateSingleResponse {
        test:assertEquals(response.done, true, "Single response should be done");
        test:assertNotEquals(response.response, "", "Response should not be empty");
    }
}

@test:Config {
    groups: ["positive_tests", "generation", "single_response", "suffix"],
    enable: false
}
function testSingleResponseWithSuffix() returns error? {
    request = {
        model: deepseek,
        prompt: prompt,
        suffix: suffix,
        'stream: false
    };
    GenerateStreamResponse|GenerateSingleResponse|error response = ollama->/generate.post(request);
    io:print("Response: ", response);
    test:assertTrue(response is GenerateSingleResponse, "Error generating single response with suffix");
    if response is GenerateSingleResponse {
        test:assertEquals(response.done, true, "Single response should be done");
    }
}

@test:Config {
    groups: ["positive_tests", "generation", "stream_response", "structured_response"]
}
function testSingleResponseWithJsonFormat() returns error? {
    request = {
        model: llama3_2,
        prompt: prompt,
        'stream: false,
        format: "json"
    };
    GenerateStreamResponse|GenerateSingleResponse|error response = ollama->/generate.post(request);
    test:assertTrue(response is GenerateSingleResponse, "Error generating single response with JSON format");
    if response is GenerateSingleResponse {
        json|error jsonParsed = response.response.fromJsonString();
        test:assertTrue(jsonParsed is json, "Response.response should be JSON");
    }
}

@test:Config {
    groups: ["negative_tests", "generation", "stream_response", "structured_response"]
}
function testSingleResponseWithJsonFormatFails() returns error? {
    request = {
        model: llama3_2,
        prompt: prompt,
        'stream: false
    };
    GenerateStreamResponse|GenerateSingleResponse|error response = ollama->/generate.post(request);
    test:assertTrue(response is GenerateSingleResponse, "Error generating single response with JSON format");
    if response is GenerateSingleResponse {
        json|error jsonParsed = response.response.fromJsonString();
        test:assertFalse(jsonParsed is json, "Response.response should be JSON");
    }
}
