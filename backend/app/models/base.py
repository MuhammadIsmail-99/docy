from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()

# Example:
# from sqlalchemy import Column, Integer, String
# class Doctor(Base):
#     __tablename__ = "doctors"
#     id = Column(Integer, primary_key=True, index=True)
#     name = Column(String)
