# The Effect of Anime Adaptation on Manga Sales

## Abstract
<!-- Brief summary of the research, focusing on the relationship between anime adaptations and manga sales -->

## Introduction
The adaptation of stories across different media forms has long been a hallmark of the entertainment industry, enabling creators to reach broader audiences and breathe new life into existing narratives. From the transformation of classic fairy tales such as _Cinderella_ and _Snow White_ into animated films and live-action productions to the cinematic successes of _The Wizard of Oz_ (1939) and the _Harry Potter_ franchise, media adaptations have consistently demonstrated their ability to captivate audiences and generate significant economic returns. In recent years, the scope of adaptations has expanded to include video games, with productions like _Arcane_ (2021), based on _League of Legends_, showcasing the potential of cross-medium storytelling to engage both dedicated fans and new viewers.

This study focuses on a specific subset of media adaptations: the relationship between Japanese anime and manga. Manga, a form of serialized graphic storytelling, often serves as the narrative foundation for anime adaptations. The process of adaptation is facilitated by the storyboard-like nature of manga, which aligns closely with the frame-by-frame animation techniques traditionally employed in anime production. However, the relationship between manga and anime is not absolute; while many anime are adapted from manga, some are original creations, and a significant portion of manga never receives an adaptation.

The economic implications of these adaptations are of particular interest. Anime adaptations have the potential to act as a form of publicity, akin to traditional advertising, by increasing the visibility of the source material and driving consumer demand. This study seeks to quantify this effect by examining the impact of anime adaptations on manga sales. Specifically, we aim to determine whether the release of an anime adaptation correlates with measurable changes in weekly manga sales trends. By leveraging a structured dataset that includes manga sales figures and anime release schedules, we employ a causal modeling approach to analyze the relationship between these variables.

Through this research, we aim to contribute to the broader understanding of media adaptation as an economic phenomenon. By focusing on the Japanese anime and manga industries, which provide a well-documented and accessible case study, we seek to uncover insights into how adaptations influence consumer behavior and market dynamics. The findings of this study have implications not only for the manga and anime industries but also for the broader field of media economics, offering a data-driven perspective on the role of adaptations in shaping cultural consumption patterns.

## Methodology

### Data Sources
The primary dataset for this study was sourced from MangaCodex, a platform that aggregates manga sales data from Oricon. Oricon Inc. (株式会社オリコン, Kabushiki-gaisha Orikon), established in 1999, is a Japanese corporate group renowned for providing statistics and information on the music and entertainment industries. Originally founded as Original Confidence Inc. (株式会社オリジナルコンフィデンス, Kabushiki-gaisha Orijinaru Konfidensu) in 1967 by Sōkō Koike, Oricon is widely recognized for its authoritative music charts. Beyond music, Oricon tracks sales data for various entertainment media, including manga, making it a reliable source for this research.

Additionally, data was collected using the AniList API, which provides detailed information on anime and manga titles, including release schedules and metadata. These datasets were instrumental in aligning manga sales data with corresponding anime adaptations for analysis.

### Data Collection
The data collection process involved multiple steps, primarily executed using Python in Jupyter Notebook. First, MangaCodex was scraped to retrieve all available links to manga sales data. These links were compiled, cleaned, and used to scrape individual pages for detailed sales information. The scraped data was then processed, cleaned, and consolidated into a structured dataset.

In parallel, the AniList API was utilized to gather relevant anime and manga data. This included querying the API for titles, release dates, and other metadata, which were saved as separate datasets. Together, these datasets formed the foundation for the analysis conducted in this study.

### Potential Issues and Limitations

While the methodology employed in this study aims to provide a robust framework for analyzing the relationship between anime adaptations and manga sales, several potential issues and limitations should be considered. To address some of these issues, a randomized selection of anime adaptations will be implemented, followed by re-running the differential model analysis. This approach aims to mitigate biases introduced by focusing solely on the most popular adaptation and to provide a more comprehensive understanding of the relationship between adaptations and sales trends.

1. **Multiple Adaptations**: Some manga series have multiple anime adaptations, which may vary in popularity and timing. By focusing on the most popular adaptation as the primary "treatment," the analysis may overlook the cumulative or sequential effects of earlier adaptations, particularly if they were less successful ("busts") before a later adaptation gained traction.

2. **Assumption of Popularity as Treatment**: The assumption that the most popular adaptation is the primary driver of manga sales may not hold in all cases. Other factors, such as marketing campaigns, concurrent media releases, or changes in consumer preferences, could also influence sales trends.

3. **Temporal Misalignment**: The categorization of sales data into pre-adaptation and post-adaptation periods assumes a clear temporal boundary. However, the impact of an adaptation may not be immediate, and there could be lag effects or anticipatory increases in sales leading up to the adaptation's release.

4. **Data Completeness**: The datasets used in this study, while comprehensive, may not capture all relevant manga titles or adaptations. Missing data or inaccuracies in sales figures and release dates could introduce bias into the analysis.

5. **Generalizability**: The findings of this study are specific to the Japanese manga and anime industries. While these industries provide a well-documented case study, the results may not be directly applicable to other forms of media adaptations or cultural contexts.

6. **Unobserved Confounding Variables**: Factors such as changes in consumer behavior, broader market trends, or external events (e.g., economic downturns or global pandemics) could influence manga sales independently of anime adaptations, potentially confounding the results.

By acknowledging these potential issues, the study aims to provide a balanced interpretation of its findings and highlight areas for future research to address these limitations.

<!-- -->

## Results
<!-- Presentation of findings -->
<!-- Present findings on how anime adaptations influence manga sales -->

## Discussion
<!-- Interpretation of results and implications -->
<!-- Discuss the implications of the findings for the manga and anime industries -->

## References
<!-- List of cited works -->
<!-- Include references to studies, data sources, and relevant literature -->

words in title

what I'm trying to show is:

do people watch an anime, then decide to read the manga..
or
do people get introduced an anime...

Pivot
Do people watch an anime, finish the season (after it ends), and go read the manga?

I can test this by looking at:
look at only manga that are adapted ->
look at all anime adaptation end date ->
DiD pre treatment vs post treatment (before or after its adaptation) 
vs. this difference between manga?

Problem: what if there isn't data because I have the top charts?

manga_sales = (treatment x post) + factor(manga series)

Exogeneity could be exact time when an anime is adapted

FE for the week and ...
Basically I have my did and these treatment time (adaptation date) is exogenous, How could I introdouce that into my model


GOAL: Weebiest poster possible