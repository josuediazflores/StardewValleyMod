import Foundation

struct DependencyWarning {
    let modName: String
    let dependentMods: [String]
    let message: String
}

enum DependencyResolver {
    /// Resolves dependencies for all mods and populates their resolvedDependencies.
    static func resolveAll(mods: [Mod]) {
        let lookup = Dictionary(mods.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        for mod in mods {
            var resolved: [ResolvedDependency] = []

            // Check explicit dependencies
            if let deps = mod.manifest.dependencies {
                for dep in deps {
                    let status: DependencyStatus
                    let depName: String?

                    if let depMod = lookup[dep.uniqueID] {
                        depName = depMod.manifest.name
                        status = depMod.isEnabled ? .satisfied : .disabled
                    } else {
                        depName = nil
                        status = .missing
                    }

                    resolved.append(ResolvedDependency(entry: dep, status: status, modName: depName))
                }
            }

            // Check ContentPackFor reference
            if let cpf = mod.manifest.contentPackFor {
                let dep = ModDependencyEntry(uniqueID: cpf.uniqueID)
                let status: DependencyStatus
                let depName: String?

                if let depMod = lookup[cpf.uniqueID] {
                    depName = depMod.manifest.name
                    status = depMod.isEnabled ? .satisfied : .disabled
                } else {
                    depName = nil
                    status = .missing
                }

                resolved.append(ResolvedDependency(entry: dep, status: status, modName: depName))
            }

            mod.resolvedDependencies = resolved
        }
    }

    /// Checks what would break if a mod is disabled. Returns warning if other mods depend on it.
    static func checkDisableImpact(mod: Mod, allMods: [Mod]) -> DependencyWarning? {
        let dependents = allMods.filter { otherMod in
            guard otherMod.isEnabled, otherMod.id != mod.id else { return false }

            // Check explicit dependencies
            if let deps = otherMod.manifest.dependencies {
                if deps.contains(where: { $0.uniqueID == mod.id && $0.isRequired }) {
                    return true
                }
            }

            // Check ContentPackFor
            if otherMod.manifest.contentPackFor?.uniqueID == mod.id {
                return true
            }

            return false
        }

        if dependents.isEmpty { return nil }

        let names = dependents.map { $0.manifest.name }
        return DependencyWarning(
            modName: mod.manifest.name,
            dependentMods: names,
            message: "Disabling \"\(mod.manifest.name)\" will affect \(names.count) mod(s) that depend on it:\n\(names.joined(separator: "\n"))"
        )
    }

    /// Checks what dependencies are missing/disabled when enabling a mod.
    static func checkEnableRequirements(mod: Mod, allMods: [Mod]) -> DependencyWarning? {
        let lookup = Dictionary(allMods.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var issues: [String] = []

        if let deps = mod.manifest.dependencies {
            for dep in deps where dep.isRequired {
                if let depMod = lookup[dep.uniqueID] {
                    if !depMod.isEnabled {
                        issues.append("\"\(depMod.manifest.name)\" is disabled")
                    }
                } else {
                    issues.append("\"\(dep.uniqueID)\" is not installed")
                }
            }
        }

        if let cpf = mod.manifest.contentPackFor {
            if let depMod = lookup[cpf.uniqueID] {
                if !depMod.isEnabled {
                    issues.append("\"\(depMod.manifest.name)\" is disabled")
                }
            } else {
                issues.append("\"\(cpf.uniqueID)\" is not installed")
            }
        }

        if issues.isEmpty { return nil }

        return DependencyWarning(
            modName: mod.manifest.name,
            dependentMods: issues,
            message: "Enabling \"\(mod.manifest.name)\" has unmet dependencies:\n\(issues.joined(separator: "\n"))"
        )
    }
}

// Allow creating a dependency entry for ContentPackFor checks
extension ModDependencyEntry {
    init(uniqueID: String) {
        self.uniqueID = uniqueID
        self.minimumVersion = nil
        self.isRequired = true
    }
}
