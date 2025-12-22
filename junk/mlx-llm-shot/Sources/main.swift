import Foundation
import ArgumentParser

struct MLXClient: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mlx-llm-cli",
        abstract: "A Swift CLI to interact with locally running MLX LLM server"
    )

    @Option(name: .shortAndLong, help: "The prompt to send to the LLM")
    var prompt: String

    @Option(name: .shortAndLong, help: "Server URL (default: http://localhost:8080)")
    var url: String = "http://localhost:8080"

    @Option(name: .shortAndLong, help: "API endpoint path (default: /v1/completions)")
    var endpoint: String = "/v1/completions"

    @Option(name: .shortAndLong, help: "Maximum tokens to generate (default: 512)")
    var maxTokens: Int = 512

    @Option(name: .shortAndLong, help: "Temperature for sampling (default: 0.7)")
    var temperature: Double = 0.7

    func run() throws {
        print("Sending prompt to MLX server at \(url)\(endpoint)...")
        print("Prompt: \(prompt)\n")

        let semaphore = DispatchSemaphore(value: 0)
        var responseText: String?
        var errorText: String?

        sendRequest(prompt: prompt) { result in
            switch result {
            case .success(let text):
                responseText = text
            case .failure(let error):
                errorText = error.localizedDescription
            }
            semaphore.signal()
        }

        semaphore.wait()

        if let response = responseText {
            print("Response:")
            print("---")
            print(response)
            print("---")
        } else if let error = errorText {
            print("Error: \(error)")
            throw ExitCode.failure
        }
    }

    func sendRequest(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "\(url)\(endpoint)") else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1)))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: Any] = [
            "prompt": prompt,
            "max_tokens": maxTokens,
            "temperature": temperature,
            "stream": false
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "No data received", code: -1)))
                return
            }

            // Check HTTP status code
            if let httpResponse = response as? HTTPURLResponse {
                guard (200...299).contains(httpResponse.statusCode) else {
                    let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
                    completion(.failure(NSError(
                        domain: "HTTP Error \(httpResponse.statusCode)",
                        code: httpResponse.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: errorMsg]
                    )))
                    return
                }
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Try to parse OpenAI-compatible response format
                    if let choices = json["choices"] as? [[String: Any]],
                       let firstChoice = choices.first,
                       let text = firstChoice["text"] as? String {
                        completion(.success(text))
                    } else if let text = json["response"] as? String {
                        // Alternative response format
                        completion(.success(text))
                    } else if let text = json["text"] as? String {
                        // Another alternative format
                        completion(.success(text))
                    } else {
                        // Return the full JSON if we can't parse it
                        let prettyData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
                        let prettyString = String(data: prettyData, encoding: .utf8) ?? "Unable to parse response"
                        completion(.success(prettyString))
                    }
                } else {
                    completion(.failure(NSError(domain: "Invalid JSON response", code: -1)))
                }
            } catch {
                completion(.failure(error))
            }
        }

        task.resume()
    }
}

MLXClient.main()
