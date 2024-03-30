//
//  MovieDetailsViewModel.swift
//  BanqueMisr-TMDB
//
//  Created by Ahmed Bahgat on 28/03/2024.
//

import Foundation
import Combine

protocol MovieDetailsViewModelInputs {
  func fetchMovieDetails() async throws -> MovieDetails
  func fetchMovieImagePoster(for posterPath:String, with width:Int) async throws -> Data
}

protocol MovieDetailsViewModelOutputs {
  var errorMessage:PassthroughSubject<String,Never> { get }
  var isLoading:PassthroughSubject<Bool,Never> { get }
  var screenTitle:String { get }
}

typealias MovieDetailsViewModel = MovieDetailsViewModelInputs & MovieDetailsViewModelOutputs

final class DefaultMovieDetailsViewModel {
  //MARK: - Properties
  private let movieDetailsUseCase:MovieDetailsUseCase
  private let movieID:String
  //MARK: - Outputs
  var errorMessage: PassthroughSubject<String, Never> = .init()
  var isLoading: PassthroughSubject<Bool, Never> = .init()
  var screenTitle: String { "Movie Details "}
  //MARK: - Init
  init(movieDetailsUseCase: MovieDetailsUseCase,
       movieID:String) {
    self.movieDetailsUseCase = movieDetailsUseCase
    self.movieID = movieID
  }
}
extension DefaultMovieDetailsViewModel:MovieDetailsViewModel {
  func fetchMovieDetails() async throws -> MovieDetails {
    do {
      self.isLoading.send(true)
      let movieDetails = try await movieDetailsUseCase.execute(for: self.movieID)
      self.isLoading.send(false)
      return movieDetails
    }catch {
      errorMessage.send(error.errorMessage)
      throw error
    }
  }
  
  func fetchMovieImagePoster(for posterPath:String,
                             with width:Int) async throws -> Data {
    return try await movieDetailsUseCase.fetchMovieImagePoster(
      for: posterPath,
      width: width
    )
  }
}
