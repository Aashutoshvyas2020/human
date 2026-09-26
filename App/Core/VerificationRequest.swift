import Foundation

struct VerificationRequest: Equatable, Sendable {
  var session: String
  var callback: URL

  init?(url: URL) {
    guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
      parts.scheme?.lowercased() == "duofold", parts.host?.lowercased() == "verify",
      parts.path.isEmpty || parts.path == "/", parts.user == nil, parts.password == nil,
      let query = parts.queryItems else { return nil }
    let sessions = query.filter { $0.name == "session" }
    let callbacks = query.filter { $0.name == "callback" }
    guard sessions.count == 1, callbacks.count == 1,
      let session = sessions.first?.value, session.count == 12,
      session.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) }),
      let value = callbacks.first?.value, value.count <= 4096,
      let callback = URLComponents(string: value), callback.scheme?.lowercased() == "https",
      let host = callback.host, !host.isEmpty, callback.user == nil, callback.password == nil,
      let callbackURL = callback.url else { return nil }
    self.session = session
    self.callback = callbackURL
  }

  func successURL(metrics: [String: Double] = [:]) -> URL {
    var parts = URLComponents(url: callback, resolvingAgainstBaseURL: false)!
    var query = (parts.queryItems ?? []).filter { !["session", "result"].contains($0.name) && !$0.name.hasPrefix("df_") }
    query += [URLQueryItem(name: "session", value: session), URLQueryItem(name: "result", value: "success")]
    query += metrics.sorted { $0.key < $1.key }.map { URLQueryItem(name: "df_" + $0.key, value: String($0.value)) }
    parts.queryItems = query
    return parts.url!
  }
}
