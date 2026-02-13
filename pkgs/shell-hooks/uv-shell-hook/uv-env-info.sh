#!/usr/bin/env bash

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

BOLD=$(tput bold)
ND=$(tput sgr0) # No decoration

show_venv_info() {

    if [ ! -d $venvDir ]; then
        echo "No virtual environment found at $venvDir"
        return 1
    fi

    local pkg_count=$(uv pip list --format=freeze 2>/dev/null | wc -l)

    echo ""
    echo -e "${BOLD}Virtual Environment Info:${ND}"
    echo -e "${BLUE}Python version:${NC} ${GREEN}$($venvDir/bin/python --version 2>&1 | cut -d' ' -f2)${NC}"
    echo -e "${BLUE}UV version:${NC}     ${GREEN}$(uv --version 2>&1 | cut -d' ' -f2)${NC}"
    echo -e "${BLUE}Path:${NC}           ${GREEN}$(cd $venvDir && pwd)${NC}"
    echo -e "${BLUE}Executable:${NC}     ${GREEN}$(realpath -s $venvDir/bin/python)${NC}"
    echo -e "${BLUE}Packages:${NC}       ${GREEN}$pkg_count installed${NC}"
}

show_venv_info
