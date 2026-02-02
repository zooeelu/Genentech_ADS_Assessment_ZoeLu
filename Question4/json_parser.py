import json  # json (converts between json text and python dicts)
import re # requests (lets you search text using patterns)
from dataclasses import dataclass # defining object and how it will look like
from langchain_core.output_parsers import BaseOutputParser # taking llm output and returning structured data 
from langchain_core.exceptions import OutputParserException # expected error when the llm output is invalid

@dataclass

# A valid AE query result should have exactly two strings (target_column) and (filter_value)
# This defines the shape of a valid AE query result
# This is what the parser will return if everything is sucessful
class AEQueryResult:
    target_column: str 
    filter_value: str 


# Only existing AE columns are allowed, anything else will throw a controlled error
VALID_COLUMNS = {
    "AETERM", "AELLT", "AEDECOD", "AEHLT", "AEHLGT","AEBODSYS", "AESOC", "AESEV", "AESER",
    "AEACN", "AEREL", "AEOUT", "AESCAN", "AESCONG", "AESDISAB", "AESDTH", "AESHOSP", "AESLIFE", "AESOD"
}

# Custom output parse for AE queries
class AEQueryOutputParser(BaseOutputParser[AEQueryResult]): 

    # helper function to handle messy llm formatting
    def _extract_json(self, text:str) -> str: 
        """
        Extracts JSON content from LLM output.
        Handles cases where JSON is wrapped in markdown or mixed with text.
        """

        text = text.strip()

        # Case 1: json inside triple brackets like for markdown
        json_match = re.search(r"```(?:json)?\s*([\s\S]*?)```", text)
        if json_match:
            return json_match.group(1).strip()

        # Case 2: First {...} block found in the text
        json_match = re.search(r"\{[\s\S]*\}", text)
        if json_match:
            return json_match.group(0)
        
        # Fallback: return original text
        return text

 
    # function called automatically after the llm responds
    def parse(self, text: str) -> AEQueryResult:
        """
        Takes raw LLM output text and converts it into an AEQueryResult.
        Raises an error if the output is invalid or unsafe.
        """

        # Extract jsut the json portion from the llm output
        clean_text = self._extract_json(text)

        # Parse json string into a python dict
        try: 
            results = json.loads(clean_text)
        except json.JSONDecodeError as e:
            raise OutputParserException(
                f"failed to load json {e}"
            )

        # Validate required field exist
        if "target_column" not in results:
            raise OutputParserException(
                f"missing taget column in response"
            )

        if "filter_value" not in results:
            raise OutputParserException(
                f"missing taget column in response"
            )

        # Validate the column name is allowes
        target_column = results['target_column'] 
        if target_column not in VALID_COLUMNS: 
            raise OutputParserException(
                f"invalid column name"
            )
        
        # Return a clean structured object
        return AEQueryResult(
            target_column = target_column, 
            filter_value = results['filter_value']
        )  



    