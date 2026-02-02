from langchain_core.language_models import BaseChatModel
import pandas as pd

# Import prompt rules, parser output type, and chain builder
from prompt import AE_SYSTEM_PROMPT
from json_parser import AEQueryOutputParser, AEQueryResult
from ae_query_chain import create_ae_chain


#   Define the main ClinicalTrialDataAgent that:
#     1) Interprets natural language AE questions using an LLM
#     2) Converts the question into a structured query
#     3) Applies the query to a clinical AE dataset using pandas
#     4) Returns matching subject IDs and a summary message

class ClinicalTrialDataAgent: 
    """
    ClinicalTrialDataAgent combines:
      - an LLM for interpreting user questions
      - a structured output parser for safety
      - pandas-based data filtering for execution

    This class represents a single chatbot agent instance.
    """
    
    def __init__(self, llm:BaseChatModel):
        self.llm = llm
        # Build the langchain pipeline: prompt -> llm -> output parser
        self.chain = create_ae_chain(llm)

    def parse_question(self, question:str) -> AEQueryResult:
        # Interpret a natural language question and return a structured query.
        return self.chain.invoke({"question": question})
    
    def query(self, df: pd.DataFrame, question: str) -> tuple[int, pd.DataFrame, str]:
        '''
        Execute a natural language query against an AE dataset.
        Steps:
          1) Use the LLM to interpret the question
          2) Apply the resulting filter to the dataframe
          3) Extract unique subject IDs
          4) Return results and a summary message
        '''
        # Interpret the question using the llm
        result = self.parse_question(question)
        target_column = result.target_column
        filter_value = result.filter_value
        
        # Build a boolean mask using case-insesitivie string matching
        mask = df[target_column].str.contains(filter_value, case=False, na=False)

        # Filter the dataframe based on mask
        filtered_df = df[mask]

        # Extract the unique subjext ids
        unique_patients = pd.DataFrame(filtered_df['USUBJID'].unique(),columns = ["IDs"])

        # Count the number of unique patients
        count = len(unique_patients)

        # Create a summary messag
        summary = (f"There are {count} matching records! \n\n"
                   f"These are the unique USUBJIDs:\n{unique_patients}")
        
        return count, unique_patients, summary

