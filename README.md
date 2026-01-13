# AliSQL with DuckDB Engine

## Overview

This repository contains **AliSQL** (Alibaba's MySQL fork) integrated with **DuckDB** as an analytical engine. This integration combines the OLTP capabilities of MySQL with the powerful OLAP features of DuckDB, providing a hybrid database solution for both transactional and analytical workloads.

## Version Information

- **AliSQL Version**: 8.0.44 (LTS)
- **Based on**: MySQL 8.0.44
- **DuckDB Engine**: Integrated as a storage/analytical engine within AliSQL

## What is AliSQL?

AliSQL is Alibaba's MySQL branch, forked from official MySQL and used extensively in Alibaba Group's production environment. It includes various performance optimizations, stability improvements, and features tailored for large-scale applications.

## What is DuckDB?

DuckDB is an open-source embedded analytical database system (OLAP) designed for data analysis workloads. DuckDB is rapidly becoming a popular choice in data science, BI tools, and embedded analytics scenarios due to its key characteristics:

- **Exceptional Query Performance**: Single-node DuckDB performance not only far exceeds InnoDB, but even surpasses ClickHouse and SelectDB
- **Excellent Compression**: DuckDB uses columnar storage and automatically selects appropriate compression algorithms based on data types, achieving very high compression ratios
- **Embedded Design**: DuckDB is an embedded database system, naturally suitable for integration into MySQL
- **Plugin Architecture**: DuckDB uses a plugin-based design, making it very convenient for third-party development and feature extensions
- **Friendly License**: DuckDB's license allows any form of use, including commercial purposes

## Why Integrate DuckDB with AliSQL?

MySQL has long lacked an analytical query engine. While InnoDB is naturally designed for OLTP and excels in TP scenarios, its query efficiency is very low for analytical workloads. This integration enables:

- **Hybrid Workloads**: Run both OLTP (MySQL/InnoDB) and OLAP (DuckDB) queries in a single database system
- **High-Performance Analytics**: Analytical query performance improves up to **200x** compared to InnoDB
- **Storage Cost Reduction**: DuckDB read replicas typically use only **20%** of the main instance's storage space due to high compression
- **100% MySQL Syntax Compatibility**: No learning curve - DuckDB is integrated as a storage engine, so users continue using MySQL syntax
- **Zero Additional Management Cost**: DuckDB instances are managed, operated, and monitored exactly like regular RDS MySQL instances
- **One-Click Deployment**: Create DuckDB read-only instances with automatic data conversion from InnoDB to DuckDB

## Architecture

### MySQL's Pluggable Storage Engine Architecture

MySQL's pluggable storage engine architecture allows it to extend its capabilities through different storage engines:

![MySQL Architecture](https://raw.githubusercontent.com/baotiao/bb/main/uPic/0f4ea5d6-b3ff-45b8-bdeb-60f03b56fe1e.png)

The architecture consists of four main layers:
- **Runtime Layer**: Handles MySQL runtime tasks like communication, access control, system configuration, and monitoring
- **Binlog Layer**: Manages binlog generation, replication, and application
- **SQL Layer**: Handles SQL parsing, optimization, and execution
- **Storage Engine Layer**: Manages data storage and access

### DuckDB Read-Only Instance Architecture

![DuckDB Architecture](https://raw.githubusercontent.com/baotiao/bb/main/uPic/a5005f18-fb41-46c5-8d11-328b4182766f.png)

DuckDB analytical read-only instances use a read-write separation architecture:
- Analytical workloads are separated from the main instance, ensuring no mutual impact
- Data replication from the main instance via binlog mechanism (similar to regular read replicas)
- InnoDB stores only metadata and system information (accounts, configurations)
- All user data resides in the DuckDB engine

## Implementation Details

### Query Path

![Query Path](https://raw.githubusercontent.com/baotiao/bb/main/uPic/ccb31673-c5cc-429d-b8bc-e432e50a7737.png)

1. Users connect via MySQL client
2. MySQL parses the query and performs necessary processing
3. SQL is sent to DuckDB engine for execution
4. DuckDB returns results to server layer
5. Server layer converts results to MySQL format and returns to client

**Compatibility**:
- Extended DuckDB's syntax parser to support MySQL-specific syntax
- Rewrote numerous DuckDB functions and added many MySQL functions
- Automated compatibility testing platform with ~170,000 SQL tests shows **99% compatibility rate**

### Binlog Replication Path

![Binlog Replication](https://raw.githubusercontent.com/baotiao/bb/main/uPic/79d99d71-1e2b-419d-977a-94d10faea090.png)

Key features:

**Idempotent Replay**:
- Since DuckDB doesn't support two-phase commit, custom transaction commit and binlog replay processes ensure data consistency after instance crashes

**DML Replay Optimization**:
- DuckDB favors large transactions; frequent small transactions cause severe replication lag
- Implemented batch replay mechanism achieving **30K rows/s** replay capability
- In Sysbench testing, achieves zero replication lag, even higher than InnoDB replay performance

**Parallel Copy DDL**:
- For DDL operations DuckDB doesn't natively support (e.g., column reordering), implemented Copy DDL mechanism
- Natively supported DDL uses Inplace/Instant execution
- Copy DDL creates a new table to replace the original using multi-threaded parallel execution
- Execution time reduced by **7x**

![Copy DDL Performance](https://raw.githubusercontent.com/baotiao/bb/main/uPic/5ddc14f2-9b8a-4a00-a346-bace639009e5.png)

## Performance Benchmarks

**Test Environment**:
- ECS Instance: 32 CPU, 128GB Memory, ESSD PL1 Cloud Disk 500GB
- Benchmark: TPC-H SF100

![Performance Comparison](https://raw.githubusercontent.com/baotiao/bb/main/uPic/f844ff93-34d5-4971-89f7-684bea81a001.png)

DuckDB demonstrates significant performance advantages over InnoDB in analytical query scenarios, with up to **200x improvement**.

## Getting Started

### Building AliSQL with DuckDB Engine

**Prerequisites**:
- [CMake](https://cmake.org) 3.x or higher
- Python3
- C++11 compliant compiler (GCC 5.x+ or Clang 3.4+)

**Build Instructions**:

```bash
# Clone the repository
git clone https://github.com/alibaba/AliSQL.git
cd AliSQL

# Build the project (release build)
sh build.sh -t release -d /path/to/install/dir

# For development/debugging (debug build)
sh build.sh -t debug -d /path/to/install/dir

# Install the built MySQL server
make install
```

**Build Options**:
- `-t release|debug`: Build type (default: debug)
- `-d <dest_dir>`: Installation directory (default: /usr/local/rds_mysql or $HOME/rds_mysql)
- `-s <server_suffix>`: Server suffix (default: rds-dev)
- `-g asan|tsan`: Enable sanitizer
- `-c`: Enable GCC coverage (gcov)
- `-h, --help`: Show help

### Using DuckDB Engine in MySQL

Once built, you can create tables using the DuckDB storage engine:

```sql
-- Create a table with DuckDB engine
CREATE TABLE analytics_table (
    id INT,
    name VARCHAR(100),
    value DECIMAL(10,2)
) ENGINE=DuckDB;

-- Import data from Parquet files
LOAD DATA INFILE '/path/to/data.parquet' INTO TABLE analytics_table;

-- Run analytical queries
SELECT name, SUM(value) as total
FROM analytics_table
GROUP BY name
ORDER BY total DESC;
```

### Configuration

Key MySQL parameters for DuckDB engine:
- Configure DuckDB-specific settings through MySQL system variables
- Refer to the documentation for tuning parameters based on your workload

## Try It on Alibaba Cloud

You can experience RDS MySQL with DuckDB engine on Alibaba Cloud:

https://help.aliyun.com/zh/rds/apsaradb-rds-for-mysql/duckdb-based-analytical-instance/

## Resources

- [DuckDB Official Documentation](https://duckdb.org/docs/stable/)
- [DuckDB GitHub Repository](https://github.com/duckdb/duckdb)
- [MySQL 8.0 Documentation](https://dev.mysql.com/doc/refman/8.0/en/)
- [Detailed Article (Chinese)](https://mp.weixin.qq.com/s/_YmlV3vPc9CksumXvXWBEw)
- [AliSQL Release Notes](./wiki/changes-in-alisql-8.0.44.2025-12-31-zh.md)

## SQL Reference

The documentation contains a [SQL introduction and reference](https://duckdb.org/docs/stable/sql/introduction).

## Development

For information on building AliSQL, see the build instructions in the **Getting Started** section above.

For detailed information on DuckDB-specific features and configuration, see:
- [DuckDB Feature Guide (Chinese)](./wiki/duckdb/duckdb-zh.md)
- [DuckDB Variables Reference (Chinese)](./wiki/duckdb/duckdb_variables-zh.md)
- [How to Setup DuckDB Node (Chinese)](./wiki/duckdb/how-to-setup-duckdb-node-zh.md)

## Repository Structure

```
AliSQL/
├── storage/duckdb/       # DuckDB storage engine implementation
│   ├── ha_duckdb.cc      # Main handler implementation
│   ├── ddl_convertor.cc  # DDL conversion layer
│   ├── dml_convertor.cc  # DML conversion layer
│   └── delta_appender.cc # Binlog replay for DuckDB
├── wiki/                 # Documentation
│   └── duckdb/          # DuckDB-specific documentation
├── build.sh             # Build script for development
├── CMakeLists.txt       # CMake configuration
└── README.md            # This file
```

## Contributing

AliSQL 8.0 became an open-source project in December 2025 and is actively maintained by engineers at Alibaba Group.

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes with appropriate tests
4. Submit a pull request

For bug reports and feature requests, please use the [GitHub Issues](https://github.com/alibaba/AliSQL/issues) page.

## Support

- **GitHub Issues**: [https://github.com/alibaba/AliSQL/issues](https://github.com/alibaba/AliSQL/issues)
- **DuckDB Documentation**: [https://duckdb.org/docs/stable/](https://duckdb.org/docs/stable/)
- **MySQL 8.0 Documentation**: [https://dev.mysql.com/doc/refman/8.0/en/](https://dev.mysql.com/doc/refman/8.0/en/)
- **Alibaba Cloud RDS**: [DuckDB-based Analytical Instance](https://help.aliyun.com/zh/rds/apsaradb-rds-for-mysql/duckdb-based-analytical-instance/)

For DuckDB-specific support, see the [DuckDB Support Options](https://duckdblabs.com/support/).

## License

This project is licensed under the GPL-2.0 license. See the [LICENSE](LICENSE) file for details.

AliSQL is based on MySQL, which is licensed under GPL-2.0. The DuckDB integration follows the same licensing terms.

