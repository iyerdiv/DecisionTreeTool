from setuptools import setup, find_packages

setup(
    name='DecisionTreeTool',
    version='1.0.0',
    description='Robust decision tree framework for systematic problem-solving and RCA',
    author='Decision Tree Tool Team',
    packages=find_packages(where='src'),
    package_dir={'': 'src'},
    python_requires='>=3.8',
    install_requires=[
        'pyyaml>=6.0',
        'typing-extensions>=4.0.0',
    ],
    extras_require={
        'dev': [
            'pytest>=7.0.0',
            'black>=22.0.0',
            'flake8>=4.0.0',
            'mypy>=0.950',
        ]
    }
)
