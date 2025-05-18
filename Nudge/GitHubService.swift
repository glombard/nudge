import Foundation

// Struct to represent Pull Request information
struct PRInfo: Decodable, Identifiable {
    let id: Int
    let title: String
    let html_url: String // The web URL for the PR
    // TODO(lombard): Consider adding 'number' to PRInfo.
    // TODO(lombard): Consider adding 'user: UserInfo' to PRInfo (requires defining UserInfo struct).
    // TODO(lombard): Consider adding 'repository: RepoInfo' to PRInfo (requires defining RepoInfo struct).
}

// Custom errors for GitHubService
enum GitHubServiceError: Error {
    case invalidURL
    case requestFailed(Error)
    case decodingError(Error)
    case patMissing
    case unexpectedResponse
    case queryConstructionError
}

class GitHubService {
    private let pat: String
    private let username: String?
    private let repositories: [String]?
    private let customQuery: String?

    init(pat: String, username: String?, repositories: [String]?, customQuery: String?) {
        self.pat = pat
        self.username = username
        self.repositories = repositories
        self.customQuery = customQuery
    }

    func fetchReviewRequests(completion: @escaping (Result<[PRInfo], GitHubServiceError>) -> Void) {
        guard !pat.isEmpty else {
            completion(.failure(.patMissing))
            return
        }

        var queryItems: [String] = ["is:open", "is:pr"]

        if let customQuery = self.customQuery, !customQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Use custom query directly if provided and not empty
            queryItems = [customQuery.trimmingCharacters(in: .whitespacesAndNewlines)]
        } else {
            // Build query based on username and repositories
            if let username = self.username, !username.isEmpty {
                queryItems.append("review-requested:\(username)")
            } else {
                // TODO(lombard): Consider if fetching without a user-specific review request filter is the desired fallback or if an error/warning is better when username is not provided.
            }

            if let repositories = self.repositories, !repositories.isEmpty {
                for repo in repositories {
                    if !repo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                         queryItems.append("repo:\(repo.trimmingCharacters(in: .whitespacesAndNewlines))")
                    }
                }
            }
        }
        
        let queryString = queryItems.joined(separator: "+").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        
        guard let finalQueryString = queryString, !finalQueryString.isEmpty else {
            completion(.failure(.queryConstructionError))
            return
        }
        
        let urlString = "https://api.github.com/search/issues?q=\(finalQueryString)"

        guard let url = URL(string: urlString) else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("token \(pat)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.requestFailed(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(.unexpectedResponse))
                return
            }

            guard let data = data else {
                completion(.failure(.unexpectedResponse)) // TODO(lombard): Consider adding a more specific error like .noData when data is nil.
                return
            }

            // GitHub search API returns items in a root object e.g., {"total_count": ..., "incomplete_results": ..., "items": [...]}
            struct SearchResult: Decodable {
                let items: [PRInfo]
            }

            do {
                let decoder = JSONDecoder()
                // TODO(lombard): Set a date decoding strategy if PRInfo includes dates
                let searchResult = try decoder.decode(SearchResult.self, from: data)
                completion(.success(searchResult.items))
            } catch {
                completion(.failure(.decodingError(error)))
            }
        }.resume()
    }
} 