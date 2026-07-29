import json

from app.utils.llm_json import extract_json


def test_extract_json_ignores_trailing_object_and_prose():
    response = (
        '{"category":"top","sub_category":"shirt"}\n'
        '{"note":"extra model output"}'
    )

    parsed = json.loads(extract_json(response))

    assert parsed == {"category": "top", "sub_category": "shirt"}


def test_extract_json_handles_markdown_fence():
    response = '```json\n{"category":"bottom"}\n```\nDone.'

    assert json.loads(extract_json(response)) == {"category": "bottom"}
