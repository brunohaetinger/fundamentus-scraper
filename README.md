# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* Migrate DB models

Generated Stocks model and migrated db with the following command:
> rails g model Stock ticker:string price:decimal pe:decimal roe:decimal p_vp:decimal div_yield:decimal fetched_at:datetime raw_html:text
> rails db:migrate
