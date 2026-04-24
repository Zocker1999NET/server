#!/usr/bin/env python3

# Original from https://gist.github.com/zlovatt/3664bf0c01292b9ae78d272548411b9d, modified for my purposes

from dataclasses import dataclass
import httpx
import os
import re
import sys # needed to be able to "nicely" exit script :)

#######################################################
# Config
#
# Ensure your .env file follows the provided example
# Or, if you rather hardcode values, remove the following lines and uncomment the lower section.
#######################################################

DEBUG_MODE=False

# Credentials
API_AUTH_TOKEN = os.getenv("API_AUTH_TOKEN")

# Connection info
#PAPERLESS_URL = os.getenv("PAPERLESS_URL", "http://localhost:8000")
PAPERLESS_URL = "http://localhost:80"
SESSION_TIMEOUT = float(os.getenv("SESSION_TIMEOUT", 5.0))

# If not using an .env file, remove the previous lines and uncomment the below
# API_AUTH_TOKEN="authtoken"
# PAPERLESS_URL = "http://localhost:8000" # use the internal url!
# SESSION_TIMEOUT = 5.0

#######################################################
# Filename parsing
#######################################################

@dataclass
class MetaData:
    start_id: int | None
    end_id: int | None
    correspondent: str | None
    document_type: str | None
    tag: str
    income_date: str | None
    "in ISO"
    title: str

def parseFileName(filename: str) -> MetaData:
    pattern = r"""(?x)(?i)^
        ((?P<start_id>\d+)-(?P<end_id>\d+)|d)
        _(?P<correspondent>[^_]*)
        _(?P<document_type>[^_]*)
        _(?P<path>[^_]*)
        _((?P<date>\d{4}-\d{2}-\d{2})|None)
        _(?P<title>.+)
        (\.pdf)?$
    """

    m = re.match(pattern, filename)
    if m is None:
        raise Exception("unmatched filename: "+filename)

    return MetaData(
        start_id=int(m.group("start_id")) if m.group("start_id") else None,
        end_id=int(m.group("end_id")) if m.group("end_id") else None,
        correspondent=m.group("correspondent"),
        document_type=m.group("document_type"),
        tag=m.group("path").replace("~","/"),
        income_date=m.group("date"),
        title=m.group("title"),
    )

#######################################################
# Database querying
#######################################################

def getItemIDByName(item_name: str, route: str, session: httpx.Client, timeout: float):
    """
    Gets an item's ID by looking up its name and API route.

    If no item exists, returns None.

    This function handles a (potentially impossible?) edge case of multiple items existing under that name; input welcome!
    """

    # Query DB for data matching name in route
    response_data = _get_resp_data(f"{route}?name__iexact={item_name}", session, timeout)
    response_count = response_data["count"]

    # If no item exists, return None
    if response_count == 0:
        print(f"No existing id found for item '{item_name}'.")
        return None

    # If one item exists, return that
    elif response_count == 1:
        new_item_id = response_data["results"][0]['id']
        print(f"Found existing id '{str(new_item_id)}' for item: '{item_name}'")
        return new_item_id

    # If multiple items exist, return the first and print a warning
    elif response_count > 1:
        print(f"Warning: Unexpected situation – multiple results found for '{item_name}'. Feedback welcome.")
        new_item_id = response_data["results"][0]['id']
        return new_item_id

    # This would be strange.
    else:
        print("Warning: Unexpected condition in getItemIDByName!")
        return new_item_id

    return new_item_id

def createItemByName(item_name: str, route: str, session: httpx.Client, timeout: float, skip_existing_check: bool = False):
    """
    Creates a new item in the database given its name and API route.

    An optional parameter is presented to skip checking for whether the item already exists.
    """

    new_item_id = None

    # Conditionally check whether the item exists
    if skip_existing_check == False:
        new_item_id = getItemIDByName(item_name, route, session, timeout)

        if new_item_id != None:
            return new_item_id

    # Create item at given route
    data = {
        "name": item_name,
        "matching_algorithm": 0, # none
        "is_insensitive": True
    }
    response = session.post(route, data=data, timeout=timeout)
    response.raise_for_status()

    new_item_id = response.json()["id"]
    print(f"Item '{item_name}' created with id: '{str(new_item_id)}'")

    # If no new_item_id has been returned, something went wrong - do not process further
    if new_item_id == None:
        print(f"Error: Couldn't create item with name '{item_name}'! Exiting.")
        sys.exit()

    return new_item_id

def getOrCreateItemIDByName(item_name: str, route: str, session: httpx.Client, timeout: float):
    # Check for existing item ID
    existing_id = getItemIDByName(item_name, route, session, timeout)

    # If no existing ID found, create
    if existing_id == None:
        print(f"No item found with name: '{item_name}'; creating...")
        existing_id = createItemByName(item_name, route, session, timeout, skip_existing_check = True)

    return existing_id

def _get_resp_data(route: str, session: httpx.Client, timeout: float):
    response = session.get(route, timeout = SESSION_TIMEOUT)
    response.raise_for_status()
    response_data = response.json()

    return response_data

def _set_auth_tokens(paperless_url: str, session: httpx.Client, timeout: float):
    response = session.get(paperless_url, timeout = timeout, follow_redirects = True)
    response.raise_for_status()

    csrf_token = response.cookies["csrftoken"]

    session.headers.update(
        {"Authorization": f"Token {API_AUTH_TOKEN}", f"X-CSRFToken": csrf_token}
    )

#######################################################
# Main
#######################################################

if DEBUG_MODE:
    from pathlib import Path
    d = Path("/home/zocker/Documents/Scans/.index/by-id")
    for f in d.iterdir():
        print(f.name)
        print(parseFileName(f.name))
elif __name__ == "__main__":
    # Running inside the Docker container
    with httpx.Client() as sess:
        # Set tokens for the appropriate header auth
        _set_auth_tokens(PAPERLESS_URL, sess, SESSION_TIMEOUT)

        # Get the PK as provided via post-consume
        doc_pk = int(os.environ["DOCUMENT_ID"])

        # Query the API for the document info
        document_api_route = f"{PAPERLESS_URL}/api/documents/{doc_pk}/"
        doc_info = _get_resp_data(document_api_route, sess, SESSION_TIMEOUT)

        # Extract the currently assigned values
        doc_title = doc_info["title"]
        print(f"Post-processing input file: '{doc_title}'...")

        # parse file name for date_created, correspondent and title for the document:
        #extracted_date, extracted_correspondent, extracted_title = parseFileName(doc_title)
        extracted = parseFileName(doc_title)

        data = {
            "id": doc_pk,
            "title": extracted.title,
            "custom_fields": [],
        }

        if extracted.start_id:
            data["custom_fields"].extend((
                {"field": 1, "value": extracted.start_id},
                {"field": 2, "value": extracted.end_id},
            ))

        if extracted.income_date:
            data["custom_fields"].append({"field": 3, "value": extracted.income_date})

        # Get correspondent ID
        if extracted.correspondent:
            correspondent_api_route = f"{PAPERLESS_URL}/api/correspondents/"
            correspondent_id = getOrCreateItemIDByName(extracted.correspondent, correspondent_api_route, sess, SESSION_TIMEOUT)
            data["correspondent"] = correspondent_id

        # Get document_type ID
        if extracted.document_type:
            document_type_api_route = f"{PAPERLESS_URL}/api/document_types/"
            document_type_id = getOrCreateItemIDByName(extracted.document_type, document_type_api_route, sess, SESSION_TIMEOUT)
            data["document_type"] = document_type_id

        # Conditionally add a tag to the document.
        if extracted.tag:
            doc_tags = doc_info["tags"]
            new_doc_tags = doc_tags

            tags_api_route = f"{PAPERLESS_URL}/api/tags/"
            tag_id = getOrCreateItemIDByName(f"legacy: {extracted.tag}", tags_api_route, sess, SESSION_TIMEOUT)

            # Add the new tag to list of current tags
            new_doc_tags.append(tag_id)

            # Set document tags
            data['tags'] = new_doc_tags

        import json
        print(json.dumps(data))

        # Update the document
        resp = sess.patch(
            f"{PAPERLESS_URL}/api/documents/{doc_pk}/",
            json=data,
            timeout=SESSION_TIMEOUT,
        )
        resp.raise_for_status()
