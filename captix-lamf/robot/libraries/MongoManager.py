from pymongo import MongoClient
from bson.objectid import ObjectId

class MongoManager:

    CONFIGS = {
    "primary_client": {"uri": "mongodb://apicore_app:ChangeMe_MongoPass_123@192.0.2.10:27017/?authSource=apicore", "db": "apicore"},
    "partner_client": {"uri": "mongodb://apicore_app:ChangeMe_MongoPass_123@192.0.2.10:27017/?authSource=apicore", "db": "partner_scheme"},
    "qa": {"uri": "mongodb://apicore_app:ChangeMe_MongoPass_123@192.0.2.10:27017/?authSource=apicore", "db": "apicore_qa"}
     }

    def __init__(self, env="dev"):
        if env not in self.CONFIGS:
            raise ValueError(f"Environment '{env}' is not defined in CONFIGS")

        current_config = self.CONFIGS[env]

        self.client = MongoClient(current_config['uri'])
        self.db = self.client[current_config['db']]

        print(f"Connected to {env} - DB: {current_config['db']}")

    def get_collection(self, collection_name):
        return self.db[collection_name]

    # Customer table
    def get_panNo_mobileNo_for_dedupe(self):
        col = self.get_collection("customer")
        doc = col.find(
            {},
            {"pan": 1, "mobile_number": 1, "_id": 0})
        return list(doc)

    def get_platform_custId_by_pan(self, pan):
        col = self.get_collection("customer")
        doc = col.find(
            {"pan": pan},
            {"platform_customer_id": 1}
        ).sort("created_at", -1).limit(1)[0]
        return str(doc["platform_customer_id"])

    def get_customer_id_by_pan(self, pan):
        col = self.get_collection("customer")
        doc = col.find(
            {"pan": pan},
            {"_id": 1}
        ).sort("created_at", -1).limit(1)[0]
        return str(doc["_id"])

    def get_loanAppId_by_loanNumber(self, loan_application_no):
        col = self.get_collection("loan_applications")
        doc = col.find(
            {"loan_application_no": loan_application_no},
            {"_id": 1}
        ).sort("_id", -1).limit(1)[0]
        return str(doc["_id"])

    # Lender-customer mapping table
    def get_lender_customer_id_by_custId(self, customer_id):
        col = self.get_collection("customer_lender_mapping")
        doc = col.find(
            {"customer_id": customer_id},
            {"lender_customer_id": 1}
        ).sort("lender_customer_id", -1).limit(1)[0]
        return str(doc["lender_customer_id"])

    # Loan application table
    def get_loanApp_No_by_custId(self, customer_id):
        col = self.get_collection("loan_applications")
        doc = col.find(
            {"customer_id": customer_id},
            {"loan_application_no": 1}
        ).sort("loan_application_no", -1).limit(1)[0]
        return str(doc["loan_application_no"])

    def get_latest_loanApp_id(self):
        col = self.get_collection("loan_applications")
        doc = col.find({}, {"_id": 1}) \
        .sort("_id", -1) \
        .limit(1)[0]
        return str(doc["_id"])

    def get_latest_loanApp_No(self, loanApp_ID):
        col = self.get_collection("loan_applications")
        query_id = ObjectId(loanApp_ID)
        result = col.find_one({"_id": query_id}, {"loan_application_no": 1})
        return result.get("loan_application_no") if result else None

    # Bank account number lookup
    def get_bankAccount_number_for_validate(self):
        col = self.get_collection("customer_bank_account_details")
        doc = col.find(
            {},
            {"bank_account_number": 1, "_id": 0})
        return list(doc)

    def close_connection(self):
        self.client.close()
