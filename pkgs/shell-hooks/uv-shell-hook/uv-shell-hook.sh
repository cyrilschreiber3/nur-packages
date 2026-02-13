# Setup hook for uv.
# shellcheck shell=bash

echo "Sourcing uv-shell-hook.sh"

uvShellHook() {
    # Skip if stdout is not a terminal (build phase)
    if [ ! -t 1 ]; then
        return 0
    fi

    echo "Executing uvShellHook"
    runHook preShellHook

    if [ -d "${venvDir}" ]; then
        echo "Skipping creation, '${venvDir}' already exists"
        source "${venvDir}/bin/activate"
    else
        if [ -n "${pythonVersion-}" ]; then
            echo "Using specified Python version: '${pythonVersion}'"
        elif [ -f ".python-version" ]; then
            pythonVersion=$(cat .python-version)
            echo "Using Python version from .python-version: '${pythonVersion}'"
        else
            echo "Error: No Python version specified. Please set 'pythonVersion' or create a .python-version file."
            exit 1
        fi

        echo "Creating new environment in path: '${venvDir}'"
        @uvBin@ venv --quiet --python ${pythonVersion} ${venvDir}

        source "${venvDir}/bin/activate"

        runHook postVenvCreation

        if [ -f "pyproject.toml" ] && [ -n "${pipPackages-}" ]; then
            echo "Warning: Both pyproject.toml exists and pipPackages are specified. Only pyproject.toml will be used for installing dependencies."
        fi

        if [ -f "pyproject.toml" ]; then
            echo "Installing dependencies with uv sync"
            @uvBin@ sync --active
        elif [ -n "${pipPackages-}" ]; then
            echo "Installing specified pip packages: ${pipPackages}"
            @uvBin@ pip install ${pipPackages}
        fi

        runHook postVenvSetup

    fi

    runHook postShellHook
    echo "Finished executing uvShellHook"
}

if [ -z "${dontUseUvShellHook:-}" ] && [ -z "${shellHook-}" ]; then
    echo "Using uvShellHook"
    if [ -z "${venvDir-}" ]; then
        echo "Error: \`venvDir\` should be set when using \`uvShellHook\`."
        exit 1
    else
        shellHook=uvShellHook
    fi
fi