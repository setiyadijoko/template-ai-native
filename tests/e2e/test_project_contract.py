from pathlib import Path


def test_project_contract_exists() -> None:
    assert Path(".template/project.yaml").is_file()
