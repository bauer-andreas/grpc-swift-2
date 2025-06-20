/*
 * Copyright 2024, gRPC Authors All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

@available(*, deprecated, renamed: "CodeGenerator")
@available(gRPCSwift 2.0, *)
public typealias SourceGenerator = CodeGenerator

/// Generates ``SourceFile`` objects containing generated code for the RPCs represented
/// in a ``CodeGenerationRequest`` object.
@available(gRPCSwift 2.0, *)
public struct CodeGenerator: Sendable {
  /// The options regarding the access level, indentation for the generated code
  /// and whether to generate server and client code.
  public var config: Config

  public init(config: Config) {
    self.config = config
  }

  /// User options for the CodeGeneration.
  public struct Config: Sendable {
    /// The access level the generated code will have.
    public var accessLevel: AccessLevel
    /// Whether imports have explicit access levels.
    public var accessLevelOnImports: Bool
    /// The indentation of the generated code as the number of spaces.
    public var indentation: Int
    /// Whether or not client code should be generated.
    public var client: Bool
    /// Whether or not server code should be generated.
    public var server: Bool
    /// The name of the core gRPC module.
    public var grpcCoreModuleName: String
    /// The availability annotations to use on the generated code.
    public var availability: AvailabilityAnnotations = .default

    /// Creates a new configuration.
    ///
    /// - Parameters:
    ///   - accessLevel: The access level the generated code will have.
    ///   - accessLevelOnImports: Whether imports have explicit access levels.
    ///   - client: Whether or not client code should be generated.
    ///   - server: Whether or not server code should be generated.
    ///   - indentation: The indentation of the generated code as the number of spaces.
    public init(
      accessLevel: AccessLevel,
      accessLevelOnImports: Bool,
      client: Bool,
      server: Bool,
      indentation: Int = 4
    ) {
      self.accessLevel = accessLevel
      self.accessLevelOnImports = accessLevelOnImports
      self.indentation = indentation
      self.client = client
      self.server = server
      self.grpcCoreModuleName = "GRPCCore"
    }

    /// The possible access levels for the generated code.
    public struct AccessLevel: Sendable, Hashable {
      package var level: Level
      package enum Level {
        case `internal`
        case `public`
        case `package`
      }

      /// The generated code will have `internal` access level.
      public static var `internal`: Self { Self(level: .`internal`) }

      /// The generated code will have `public` access level.
      public static var `public`: Self { Self(level: .`public`) }

      /// The generated code will have `package` access level.
      public static var `package`: Self { Self(level: .`package`) }
    }

    // The availability that generated code is annotated with.
    public struct AvailabilityAnnotations: Sendable, Hashable {
      public struct Platform: Sendable, Hashable {
        /// The name of the OS, e.g. 'macOS'.
        public var os: String
        /// The version of the OS, e.g. '15.0'.
        public var version: String

        public init(os: String, version: String) {
          self.os = os
          self.version = version
        }
      }

      fileprivate enum Wrapped: Sendable, Hashable {
        case macOS15Aligned
        case custom([Platform])
      }

      fileprivate var wrapped: Wrapped

      private init(_ wrapped: Wrapped) {
        self.wrapped = wrapped
      }

      /// Use the default availability.
      ///
      /// The default platform availability is:
      /// - macOS 15.0
      /// - iOS 18.0
      /// - tvOS 18.0
      /// - watchOS 11.0
      /// - visionOS 2.0
      public static var `default`: Self {
        Self(.macOS15Aligned)
      }

      /// Use a custom set of availability attributes.
      /// - Parameter platforms: Availability requirements.
      public static func custom(_ platforms: [Platform]) -> Self {
        Self(.custom(platforms))
      }
    }
  }

  /// Transforms a ``CodeGenerationRequest`` object  into a ``SourceFile`` object containing
  /// the generated code.
  public func generate(
    _ request: CodeGenerationRequest
  ) throws -> SourceFile {
    let translator = IDLToStructuredSwiftTranslator()
    let textRenderer = TextBasedRenderer(indentation: self.config.indentation)

    let structuredSwiftRepresentation = try translator.translate(
      codeGenerationRequest: request,
      accessLevel: self.config.accessLevel,
      accessLevelOnImports: self.config.accessLevelOnImports,
      client: self.config.client,
      server: self.config.server,
      grpcCoreModuleName: self.config.grpcCoreModuleName,
      availability: AvailabilityDescription(self.config.availability)
    )

    let sourceFile = try textRenderer.render(structured: structuredSwiftRepresentation)

    return sourceFile
  }
}

@available(gRPCSwift 2.0, *)
extension AvailabilityDescription {
  init(_ availability: CodeGenerator.Config.AvailabilityAnnotations) throws {
    switch availability.wrapped {
    case .macOS15Aligned:
      self = .macOS15Aligned
    case .custom(let platforms):
      self.osVersions = platforms.map {
        .init(os: .init(name: $0.os), version: $0.version)
      }
    }
  }
}
