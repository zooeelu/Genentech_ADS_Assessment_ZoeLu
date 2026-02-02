# Build a LangChain "chain" that converts a natural language user question
# into a structured AEQueryResult (target_column + filter_value).
# Prompt (system instructions + user question)
#    -> LLM (generates JSON text)
#    -> Parser (validates JSON + returns AEQueryResult object)
from langchain_core.prompts import ChatPromptTemplate, SystemMessagePromptTemplate, HumanMessagePromptTemplate
from langchain_core.language_models import BaseChatModel

# Import the system prompt text that describes the AE schema + formatting rules
from prompt import AE_SYSTEM_PROMPT

# Import our custom output parser that converts JSON text into AEQueryResult
from json_parser import AEQueryOutputParser, AEQueryResult



def create_ae_chain(llm: BaseChatModel): 
    '''
    Create a LangChain pipeline that:
      1) Inserts the user's question into a prompt with AE_SYSTEM_PROMPT
      2) Sends the prompt to the chat model (llm)
      3) Parses the LLM output into a validated AEQueryResult
    '''

    # Build a chat prompt with 
    #    - a system message (instructions + schema)
    #    - a human message containing the variable (question)
    prompt = ChatPromptTemplate.from_messages([
        SystemMessagePromptTemplate.from_template(AE_SYSTEM_PROMPT), 
        HumanMessagePromptTemplate.from_template("{question}")
    ]
    )

    # Create the output parser that will extract json from llm, validate keys, return an AEQueryResult 
    parser = AEQueryOutputParser()

    # Create the pipeline/chain using Langchain's pipe operator
    chain = prompt | llm | parser 

    return chain 
