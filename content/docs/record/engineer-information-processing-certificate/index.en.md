---
title: Information Processing Engineer Certificate Theory Summary
---

## 1. DB

### 1.1. SQL Types

* DDL (Data Definition Language)
  * CREATE : Creates a Table.
    * ex) CREATE TABLE Persons ( PersonID int, LastName varchar(255) );
  * ALTER : Modifies a Table.
    * ex) ALTER TABLE Persons ADD Email varchar(255);
    * ex) ALTER TABLE Persons DROP Email;
    * ex) ALTER TABLE Persons MODIFY ( Email varchar(128) );
    * ex) ALTER TABLE Persons RENAME Email TO Address;
  * DROP : Deletes a Table.
    * ex) DROP TABLE Persons; 
  * TRUNCATE : Deletes all contents of a Table.
    * ex) TRUNCATE TABLE Persons;
* DML (Data Manipulation Language)
  * SELECT : Reads Data from a Table.
    * ex) SELECT PersonID, LastName FROM Persons WHERE PersonID = 1;
    * ex) SELECT PersonID, LastName FROM Persons WHERE PersonID IN (1, 2);
    * ex) SELECT PersonID, LastName FROM Persons BETWEEN 1 AND 10;
    * ex) SELECT * FROM Persons;
  * INSERT : Inserts Data into a Table.
    * ex) INSERT INTO Persons (PersonID, LastName) VALUES (1 , ssup2);
  * UPDATE : Modifies Data in a Table.
    * ex) UPDATE Persons SET PersonID = 10 WHERE LastName = 'ssup2';
  * DELETE : Deletes Data from a Table.
    * ex) DELETE FROM Persons WHERE PersonID = 1;
* DCL (Data Control Language)
  * COMMIT : Applies changes.
  * ROLLBACK : Reverts changes without applying them.
  * GRANT : Grants usage permissions.
  * REVOKE : Revokes usage permissions.

### 1.2. Table Structure

* Degree : Number of Rows (Attributes, Tuple, Record)
* Cardinality : Number of Columns
* Super Key (Super Key): Refers to a set of one or more attributes that can uniquely identify each row.
* Candidate Key (Candidate Key) : Refers to a minimal set of attributes that can uniquely identify each row.
* Primary Key (Primary Key) : Refers to a key selected from among candidate keys.
* Alternate Key (Alternate Key) : When there are two or more candidate keys, one is designated as the primary key, and the remaining candidate keys are called alternate keys.
* Foreign Key (Foreign Key) : Refers to a Key used to represent relationships between Tables.

### 1.3. Index

* Clustered Index : Refers to an Index in the form of an English dictionary. Only one can exist per Table.
* Non-Clustered Index : Refers to an Index in the form of a book's index. Multiple can exist per Table.

### 1.4. Normalization

* Full Functional Dependency : Refers to the case where one attribute depends on all primary keys.
* Partial Functional Dependency : Refers to the case where one attribute depends on part of the primary key.
* Transitive Functional Dependency : Refers to the case where X->Y, Y->Z, and X->Z relationship exists.
* 1NF : Refers to the process of changing so that one attribute has a single value.
* 2NF : Refers to the process of satisfying 1NF conditions while satisfying full functional dependency.
* 3NF : Refers to the process of satisfying 2NF conditions while removing transitive functional dependency.
* BCNF : Refers to the process of satisfying 3NF conditions while removing determinant functional dependency.
* 4NF : Refers to the process of satisfying BCNF conditions while removing multivalued dependency.
* 5NF : Refers to the process of satisfying 4NF conditions while removing join dependency.

### 1.5. Anomaly

* Insertion Anomaly : Refers to the phenomenon where unwanted data must also be inserted when inserting data.
* Update Anomaly : Refers to the phenomenon where only part of the data is changed when updating data, breaking consistency.
* Deletion Anomaly : Refers to the phenomenon where unwanted data must also be deleted when deleting data.

### 1.6. Transaction ACID

* Atomicity : A Transaction has only two states: performed or not performed. 
* Consistency : Consistency must be maintained even after Transaction execution.
* Isolation : A Transaction should not affect the operation of other Transactions.
* Durability : Completed Transactions must be permanently reflected.

### 1.7 Relational Algebra

* Union U
* Intersection ∩
* Difference -
* Cartesian Product X

### 1.8 Pure Relational Operators

* Select σ : Refers to an operation that finds tuples satisfying conditions.
* Project π : Refers to an operation that extracts only specific attributes from tuples.
* Join ⋈ : Refers to an operation that creates one relation by combining two relations with common attributes.
* Division ÷ : Refers to an operation that finds only attributes on the right-hand side from tuples that have attributes present in both relations.

### 1.9 Schema

* External Schema : External schema refers to the logical structure of the database needed from the perspective of each individual user or programmer.
* Conceptual Schema : Conceptual schema refers to the overall logical structure of the database.
* Internal Schema : Internal schema represents the structure of the database from the perspective of physical storage devices.

### 1.10 ETC

* Referential Integrity : Refers to a constraint condition meaning that foreign key values that cannot be referenced cannot be held.
* System Catalog : Refers to a system database that contains information about various objects that the system itself needs.
* Data Warehouse : Refers to a separate database for decision support.

## 2. Business Process

* ERP (Enterprise Resource Planning) : Enterprise asset management
* CRM (Customer Relationship Management) : Customer relationship management
* SCM (Supply Chain Management) : Supply chain management
* EIP (Enterprise Integration Patterns) : Enterprise integrated information system

## 3. References

* DB Table Key : [https://jerryjerryjerry.tistory.com/49](https://jerryjerryjerry.tistory.com/49)

