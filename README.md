# Database Normalization

I take a dataset contained in a CSV file (called movies.csv), of movie information, clean it and turn it into a nice, normalized set of tables.

  ![image](https://user-images.githubusercontent.com/39645726/218030973-7557d121-2ec5-42cf-b7e8-13a1692764ae.png) 
   <!-- ![image](https://user-images.githubusercontent.com/39645726/218031099-cadfb0c8-8c4e-4c16-aaf0-95ef98127b37.png) -->

## Tables


**Initial movie table** 

![initial_db drawio](https://user-images.githubusercontent.com/39645726/218034375-2032f153-4eb1-4a82-a740-2a0d0774326b.png)


**Normalized set of tables**

![sql_er_diagram drawio](https://user-images.githubusercontent.com/39645726/218037502-5d7a3e98-4de8-4ded-8a63-1c326b80b762.png)

## Steps for normalization

```[tasklist]
- [X] Remove special characters from columns **movies** & **year**
- [X] Set null values in empty rows
- [X] Trim spaces and remove newlines from columns
- [X] Remove multivalues
- [X] Remove duplicate values
- [X] Find Functional Dependencies
- [X] Decompose Tables
- [X] Set surrogate keys 
- [X] Check for lossless joins
```

## Functions & Techniques 

- aggregate functions
- window functions
- views
- joins
- unions
- unnest()
- replace()
- substring()
- trim()
- nullif()
- regexp_replace()
- left()
- right()
- string_to_array()
- cast()

## Getting started

1. Clone repository	
```bash
	$ git clone https://github.com/AposLaz/POSTGRESQL_NORMALIZATION.git
		
	$ cd POSTGRESQL_NORMALIZATION

	# Remove current origin repo
	$ git remote remove origin  
```
